//
//  OverlayView+HitTesting.swift
//  Annotate
//
//  Created by Sun on 2026/11/9.
//

import Cocoa

extension OverlayView {
    // MARK: - Selection and Hit Testing
    
    private func isFadedOut(_ object: SelectedObject) -> Bool {
        guard fadeMode else { return false }
        let now = fadeClock()
        let fade = fade
        switch object {
        case .arrow(let index):
            guard index < arrows.count else { return true }
            return fade.alpha(creationTime: arrows[index].creationTime, at: now) == nil
        case .line(let index):
            guard index < lines.count else { return true }
            return fade.alpha(creationTime: lines[index].creationTime, at: now) == nil
        case .rectangle(let index):
            guard index < rectangles.count else { return true }
            return fade.alpha(for: rectangles[index], at: now) == nil
        case .circle(let index):
            guard index < circles.count else { return true }
            return fade.alpha(creationTime: circles[index].creationTime, at: now) == nil
        case .counter(let index):
            guard index < counterAnnotations.count else { return true }
            return fade.alpha(creationTime: counterAnnotations[index].creationTime, at: now) == nil
        case .path(let index):
            guard index < paths.count else { return true }
            return fade.alpha(creationTime: paths[index].creationTime, at: now) == nil
        case .highlight(let index):
            guard index < highlightPaths.count else { return true }
            return fade.alpha(creationTime: highlightPaths[index].creationTime, at: now) == nil
        case .text(let index):
            guard index < textAnnotations.count else { return true }
            return fade.alpha(creationTime: textAnnotations[index].creationTime, at: now) == nil
        case .none:
            return false
        }
    }

    /// Find object at point, checking in reverse order (topmost/latest first)
    func findObjectAt(point: NSPoint) -> SelectedObject {
        // Walk the redaction layers newest first, mirroring how draw stacks them: the
        // annotations above a redaction, then the redaction itself, then what it covers.
        var layer = RedactionLayer()
        for index in redactionIndicesByCreation.reversed() {
            layer.start = RedactionLayer.time(of: rectangles[index].creationTime)
            if let object = findAnnotation(at: point, in: layer) { return object }
            if !isFadedOut(.rectangle(index: index)) && hitTestRectangle(rectangles[index], point: point) {
                return .rectangle(index: index)
            }
            layer = RedactionLayer(end: layer.start)
        }
        return findAnnotation(at: point, in: layer) ?? .none
    }

    /// The topmost non-redaction annotation created within `layer` that contains `point`.
    private func findAnnotation(at point: NSPoint, in layer: RedactionLayer) -> SelectedObject? {
        // Check in reverse order - last drawn is on top

        // 1. Check counters
        for (index, counter) in counterAnnotations.enumerated().reversed() where layer.contains(counter.creationTime) {
            if isFadedOut(.counter(index: index)) { continue }
            if hitTestCounter(counter, point: point) {
                return .counter(index: index)
            }
        }
        
        // 2. Check text annotations
        for (index, text) in textAnnotations.enumerated().reversed() where layer.contains(text.creationTime) {
            if hitTestText(text, point: point) {
                return .text(index: index)
            }
        }
        
        // 3. Check circles
        for (index, circle) in circles.enumerated().reversed() where layer.contains(circle.creationTime) {
            if isFadedOut(.circle(index: index)) { continue }
            if hitTestCircle(circle, point: point) {
                return .circle(index: index)
            }
        }
        
        // 4. Check rectangles
        for (index, rect) in rectangles.enumerated().reversed()
            where !rect.isRedaction && layer.contains(rect.creationTime)
        {
            if isFadedOut(.rectangle(index: index)) { continue }
            if hitTestRectangle(rect, point: point) {
                return .rectangle(index: index)
            }
        }
        
        // 5. Check highlight paths
        for (index, path) in highlightPaths.enumerated().reversed() where layer.contains(path.creationTime) {
            if isFadedOut(.highlight(index: index)) { continue }
            if hitTestPath(path, tool: .highlighter, point: point) {
                return .highlight(index: index)
            }
        }
        
        // 6. Check regular paths
        for (index, path) in paths.enumerated().reversed() where layer.contains(path.creationTime) {
            if isFadedOut(.path(index: index)) { continue }
            if hitTestPath(path, tool: .pen, point: point) {
                return .path(index: index)
            }
        }
        
        // 7. Check lines
        for (index, line) in lines.enumerated().reversed() where layer.contains(line.creationTime) {
            if isFadedOut(.line(index: index)) { continue }
            if hitTestLine(line, point: point) {
                return .line(index: index)
            }
        }
        
        // 8. Check arrows
        for (index, arrow) in arrows.enumerated().reversed() where layer.contains(arrow.creationTime) {
            if isFadedOut(.arrow(index: index)) { continue }
            if hitTestArrow(arrow, point: point) {
                return .arrow(index: index)
            }
        }
        
        return nil
    }
    
    func findObjectsInRect(_ rect: NSRect) -> Set<SelectedObject> {
        var foundObjects = Set<SelectedObject>()

        let objectCollections: [(count: Int, factory: (Int) -> SelectedObject)] = [
            (counterAnnotations.count, { .counter(index: $0) }),
            (textAnnotations.count, { .text(index: $0) }),
            (circles.count, { .circle(index: $0) }),
            (rectangles.count, { .rectangle(index: $0) }),
            (highlightPaths.count, { .highlight(index: $0) }),
            (paths.count, { .path(index: $0) }),
            (lines.count, { .line(index: $0) }),
            (arrows.count, { .arrow(index: $0) })
        ]

        for (count, factory) in objectCollections {
            for i in 0..<count {
                let selectedObject = factory(i)
                if isFadedOut(selectedObject) { continue }
                if objectIntersectsRect(selectedObject, rect: rect) {
                    foundObjects.insert(selectedObject)
                }
            }
        }

        return foundObjects
    }
    
    /// Check if an object intersects with a rectangle
    private func objectIntersectsRect(_ object: SelectedObject, rect: NSRect) -> Bool {
        switch object {
        case .arrow(let index):
            guard index < arrows.count else { return false }
            let arrow = arrows[index]
            return lineSegmentIntersectsRect(start: arrow.startPoint, end: arrow.endPoint, rect: rect)
            
        case .line(let index):
            guard index < lines.count else { return false }
            let line = lines[index]
            return lineSegmentIntersectsRect(start: line.startPoint, end: line.endPoint, rect: rect)
            
        case .rectangle(let index):
            guard index < rectangles.count else { return false }
            let r = rectangles[index]
            let objRect = NSRect(
                x: min(r.startPoint.x, r.endPoint.x),
                y: min(r.startPoint.y, r.endPoint.y),
                width: abs(r.endPoint.x - r.startPoint.x),
                height: abs(r.endPoint.y - r.startPoint.y)
            )
            return rect.intersects(objRect)
            
        case .circle(let index):
            guard index < circles.count else { return false }
            let c = circles[index]
            let circleRect = NSRect(
                x: min(c.startPoint.x, c.endPoint.x),
                y: min(c.startPoint.y, c.endPoint.y),
                width: abs(c.endPoint.x - c.startPoint.x),
                height: abs(c.endPoint.y - c.startPoint.y)
            )
            return rect.intersects(circleRect)
            
        case .path(let index):
            guard index < paths.count else { return false }
            let path = paths[index]
            for point in path.points {
                if rect.contains(point.point) {
                    return true
                }
            }
            return false
            
        case .highlight(let index):
            guard index < highlightPaths.count else { return false }
            let path = highlightPaths[index]
            for point in path.points {
                if rect.contains(point.point) {
                    return true
                }
            }
            return false
            
        case .text(let index):
            guard index < textAnnotations.count else { return false }
            let textRect = getTextRect(for: textAnnotations[index])
            return rect.intersects(textRect)
            
        case .counter(let index):
            guard index < counterAnnotations.count else { return false }
            return rect.intersects(counterAnnotations[index].badgeRect)

        case .none:
            return false
        }
    }

    /// Check if a line segment intersects with a rectangle
    private func lineSegmentIntersectsRect(start: NSPoint, end: NSPoint, rect: NSRect) -> Bool {
        // Check if either endpoint is inside the rectangle
        if rect.contains(start) || rect.contains(end) {
            return true
        }
        
        // Check if line intersects any edge of the rectangle
        let edges = [
            (NSPoint(x: rect.minX, y: rect.minY), NSPoint(x: rect.maxX, y: rect.minY)), // Bottom
            (NSPoint(x: rect.maxX, y: rect.minY), NSPoint(x: rect.maxX, y: rect.maxY)), // Right
            (NSPoint(x: rect.maxX, y: rect.maxY), NSPoint(x: rect.minX, y: rect.maxY)), // Top
            (NSPoint(x: rect.minX, y: rect.maxY), NSPoint(x: rect.minX, y: rect.minY))  // Left
        ]
        
        for (edgeStart, edgeEnd) in edges {
            if lineSegmentsIntersect(p1: start, p2: end, p3: edgeStart, p4: edgeEnd) {
                return true
            }
        }
        
        return false
    }
    
    /// Check if two line segments intersect
    private func lineSegmentsIntersect(p1: NSPoint, p2: NSPoint, p3: NSPoint, p4: NSPoint) -> Bool {
        let d = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x)
        if abs(d) < 0.001 { return false } // Parallel lines
        
        let t = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / d
        let u = ((p3.x - p1.x) * (p2.y - p1.y) - (p3.y - p1.y) * (p2.x - p1.x)) / d
        
        return t >= 0 && t <= 1 && u >= 0 && u <= 1
    }
    
    // MARK: - Hit Test Methods
    
    private func hitTestLine(_ line: Line, point: NSPoint) -> Bool {
        let baseTolerance = line.lineWidth / 2.0
        let minClickableTolerance: CGFloat = 5.0
        let tolerance = max(baseTolerance, minClickableTolerance)
        
        return distanceFromPointToLineSegment(
            point: point,
            lineStart: line.startPoint,
            lineEnd: line.endPoint
        ) <= tolerance
    }
    
    private func hitTestArrow(_ arrow: Arrow, point: NSPoint) -> Bool {
        let baseTolerance = arrow.lineWidth / 2.0
        let minClickableTolerance: CGFloat = 5.0
        let tolerance = max(baseTolerance, minClickableTolerance)
        
        // Check the main line
        let lineDistance = distanceFromPointToLineSegment(
            point: point,
            lineStart: arrow.startPoint,
            lineEnd: arrow.endPoint
        )
        
        if lineDistance <= tolerance {
            return true
        }
        
        // Also check if point is inside the arrowhead triangle
        let sideLength: CGFloat = max(10.0, arrow.lineWidth * 4.0)
        let dx = arrow.endPoint.x - arrow.startPoint.x
        let dy = arrow.endPoint.y - arrow.startPoint.y
        let angle = atan2(dy, dx)
        let height = sideLength * sqrt(3.0) / 2.0
        let halfBase = sideLength / 2.0
        
        let baseCenter = NSPoint(
            x: arrow.endPoint.x - height * cos(angle),
            y: arrow.endPoint.y - height * sin(angle)
        )
        
        let perpAngle = angle + .pi / 2
        let p1 = NSPoint(
            x: baseCenter.x + halfBase * cos(perpAngle),
            y: baseCenter.y + halfBase * sin(perpAngle)
        )
        let p2 = NSPoint(
            x: baseCenter.x - halfBase * cos(perpAngle),
            y: baseCenter.y - halfBase * sin(perpAngle)
        )
        
        return isPointInTriangle(point: point, v1: arrow.endPoint, v2: p1, v3: p2)
    }
    
    private func hitTestPath(_ path: DrawingPath, tool: ToolType, point: NSPoint) -> Bool {
        let baseTolerance = path.lineWidth * tool.strokeWidthMultiplier / 2
        let tolerance = max(baseTolerance, 5)

        guard path.points.count >= 2 else {
            guard let pathPoint = path.points.first?.point else { return false }
            return hypot(point.x - pathPoint.x, point.y - pathPoint.y) <= tolerance
        }

        for index in 0..<(path.points.count - 1) {
            let distance = distanceFromPointToLineSegment(
                point: point,
                lineStart: path.points[index].point,
                lineEnd: path.points[index + 1].point
            )
            if distance <= tolerance {
                return true
            }
        }
        return false
    }
    
    
    private func hitTestRectangle(_ rect: Rectangle, point: NSPoint) -> Bool {
        let bounds = rect.bounds

        // Outlines hit on the edge only; redactions (below) hit anywhere inside
        let baseTolerance = rect.lineWidth / 2.0
        let minClickableTolerance: CGFloat = 5.0
        let edgeTolerance = max(baseTolerance, minClickableTolerance)
        
        // Expand and shrink to create edge zone
        let outerBounds = bounds.insetBy(dx: -edgeTolerance, dy: -edgeTolerance)
        let innerBounds = bounds.insetBy(dx: edgeTolerance, dy: edgeTolerance)

        // A redaction is a filled block, so its whole area is clickable.
        if rect.isRedaction { return outerBounds.contains(point) }

        // Point is on edge if it's in outer but not in inner
        return outerBounds.contains(point) && !innerBounds.contains(point)
    }
    
    private func hitTestCircle(_ circle: Circle, point: NSPoint) -> Bool {
        let bounds = NSRect(
            x: min(circle.startPoint.x, circle.endPoint.x),
            y: min(circle.startPoint.y, circle.endPoint.y),
            width: abs(circle.endPoint.x - circle.startPoint.x),
            height: abs(circle.endPoint.y - circle.startPoint.y)
        )
        
        let centerX = bounds.midX
        let centerY = bounds.midY
        let radiusX = bounds.width / 2
        let radiusY = bounds.height / 2
        
        let dx = (point.x - centerX) / radiusX
        let dy = (point.y - centerY) / radiusY
        let normalizedDistance = sqrt(dx * dx + dy * dy)
        
        // Only check edge/perimeter (not inside)
        let baseTolerance = circle.lineWidth / 2.0
        let minClickableTolerance: CGFloat = 5.0
        let edgeTolerance = max(baseTolerance, minClickableTolerance)
        
        let toleranceNormalized = edgeTolerance / min(radiusX, radiusY)
        
        // Point is on edge if distance is between (1.0 - tolerance) and (1.0 + tolerance)
        let innerBoundary = max(0, 1.0 - toleranceNormalized)
        let outerBoundary = 1.0 + toleranceNormalized
        
        return normalizedDistance >= innerBoundary && normalizedDistance <= outerBoundary
    }
    
    private func hitTestText(_ text: TextAnnotation, point: NSPoint) -> Bool {
        let textRect = getTextRect(for: text)
        return textRect.contains(point)
    }
    
    static var plainLabelSlop: NSEdgeInsets { AnnotationRenderer.plainLabelSlop }

    /// Space between a selected label's text and the dashed box (and its side handles) drawn
    /// on it. Kept in one place so drawing and the resize math agree on where the edges are.
    static let selectionPadding: CGFloat = 5.0

    func getTextRect(for annotation: TextAnnotation) -> NSRect {
        AnnotationRenderer.textRect(for: annotation)
    }
    
    private func hitTestCounter(_ counter: CounterAnnotation, point: NSPoint) -> Bool {
        let radius = counter.radius
        let dx = point.x - counter.position.x
        let dy = point.y - counter.position.y
        let distance = sqrt(dx * dx + dy * dy)
        return distance <= radius
    }
    
    // MARK: - Helper Methods
    
    private func isPointInTriangle(point: NSPoint, v1: NSPoint, v2: NSPoint, v3: NSPoint) -> Bool {
        let denominator = ((v2.y - v3.y) * (v1.x - v3.x) + (v3.x - v2.x) * (v1.y - v3.y))
        guard denominator != 0 else { return false }
        
        let a = ((v2.y - v3.y) * (point.x - v3.x) + (v3.x - v2.x) * (point.y - v3.y)) / denominator
        let b = ((v3.y - v1.y) * (point.x - v3.x) + (v1.x - v3.x) * (point.y - v3.y)) / denominator
        let c = 1 - a - b
        
        return a >= 0 && a <= 1 && b >= 0 && b <= 1 && c >= 0 && c <= 1
    }
    
    private func distanceFromPointToLineSegment(point: NSPoint, lineStart: NSPoint, lineEnd: NSPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy
        
        if lengthSquared == 0 {
            let pdx = point.x - lineStart.x
            let pdy = point.y - lineStart.y
            return sqrt(pdx * pdx + pdy * pdy)
        }
        
        var t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared
        t = max(0, min(1, t))
        
        let nearestX = lineStart.x + t * dx
        let nearestY = lineStart.y + t * dy
        
        let pdx = point.x - nearestX
        let pdy = point.y - nearestY
        return sqrt(pdx * pdx + pdy * pdy)
    }

    // MARK: - Eraser Logic

    func eraseAtPoint(_ point: NSPoint) {
        var deleted = AnnotationSnapshot()

        // Check pen paths
        for (index, path) in paths.enumerated().reversed() {
            if pathIntersectsPoint(path, tool: .pen, point: point, radius: eraserRadius) {
                deleted.paths.append(path)
                paths.remove(at: index)
            }
        }

        // Check highlighter paths
        for (index, path) in highlightPaths.enumerated().reversed() {
            if pathIntersectsPoint(path, tool: .highlighter, point: point, radius: eraserRadius) {
                deleted.highlights.append(path)
                highlightPaths.remove(at: index)
            }
        }

        // Check arrows
        for (index, arrow) in arrows.enumerated().reversed() {
            if lineIntersectsPoint(arrow.startPoint, arrow.endPoint, point: point, radius: eraserRadius) {
                deleted.arrows.append(arrow)
                arrows.remove(at: index)
            }
        }

        // Check lines
        for (index, line) in lines.enumerated().reversed() {
            if lineIntersectsPoint(line.startPoint, line.endPoint, point: point, radius: eraserRadius) {
                deleted.lines.append(line)
                lines.remove(at: index)
            }
        }

        // Check rectangles
        for (index, rectangle) in rectangles.enumerated().reversed() {
            if rectangleIntersectsPoint(rectangle, point: point, radius: eraserRadius) {
                // Undo resamples instead of restoring an old capture.
                var erased = rectangle
                erased.sample = nil
                deleted.rectangles.append(erased)
                rectangles.remove(at: index)
            }
        }

        // Check circles
        for (index, circle) in circles.enumerated().reversed() {
            if circleIntersectsPoint(circle, point: point, radius: eraserRadius) {
                deleted.circles.append(circle)
                circles.remove(at: index)
            }
        }

        // Check text annotations
        for (index, text) in textAnnotations.enumerated().reversed() {
            if textIntersectsPoint(text, point: point, radius: eraserRadius) {
                deleted.textAnnotations.append(text)
                textAnnotations.remove(at: index)
            }
        }

        // Check counter annotations
        for (index, counter) in counterAnnotations.enumerated().reversed() {
            if counterIntersectsPoint(counter, point: point, radius: eraserRadius) {
                deleted.counterAnnotations.append(counter)
                counterAnnotations.remove(at: index)
            }
        }

        // Register undo only if something was deleted
        if !deleted.isEmpty {
            registerUndo(action: .eraseAnnotations(deleted))
        }
    }

    private func pathIntersectsPoint(
        _ path: DrawingPath,
        tool: ToolType,
        point: NSPoint,
        radius: CGFloat
    ) -> Bool {
        let hitRadius = radius + path.lineWidth * tool.strokeWidthMultiplier / 2
        for timedPoint in path.points {
            let distance = hypot(timedPoint.point.x - point.x, timedPoint.point.y - point.y)
            if distance <= hitRadius {
                return true
            }
        }
        return false
    }

    private func lineIntersectsPoint(_ start: NSPoint, _ end: NSPoint, point: NSPoint, radius: CGFloat) -> Bool {
        let distance = distanceFromPointToLineSegment(point: point, lineStart: start, lineEnd: end)
        return distance <= radius
    }

    private func rectangleIntersectsPoint(_ rectangle: Rectangle, point: NSPoint, radius: CGFloat) -> Bool {
        // Check if point is near any of the four edges
        let bounds = rectangle.bounds

        // A redaction is a filled block, so the eraser removes it from anywhere inside.
        if rectangle.isRedaction && bounds.insetBy(dx: -radius, dy: -radius).contains(point) {
            return true
        }

        let topLeft = NSPoint(x: bounds.minX, y: bounds.minY)
        let topRight = NSPoint(x: bounds.maxX, y: bounds.minY)
        let bottomLeft = NSPoint(x: bounds.minX, y: bounds.maxY)
        let bottomRight = NSPoint(x: bounds.maxX, y: bounds.maxY)

        return lineIntersectsPoint(topLeft, topRight, point: point, radius: radius) ||
               lineIntersectsPoint(topRight, bottomRight, point: point, radius: radius) ||
               lineIntersectsPoint(bottomRight, bottomLeft, point: point, radius: radius) ||
               lineIntersectsPoint(bottomLeft, topLeft, point: point, radius: radius)
    }

    private func circleIntersectsPoint(_ circle: Circle, point: NSPoint, radius: CGFloat) -> Bool {
        let bounds = NSRect(
            x: min(circle.startPoint.x, circle.endPoint.x),
            y: min(circle.startPoint.y, circle.endPoint.y),
            width: abs(circle.endPoint.x - circle.startPoint.x),
            height: abs(circle.endPoint.y - circle.startPoint.y)
        )

        let centerX = bounds.midX
        let centerY = bounds.midY
        let radiusX = bounds.width / 2
        let radiusY = bounds.height / 2

        // Distance from point to ellipse edge (approximate)
        let dx = point.x - centerX
        let dy = point.y - centerY
        let normalizedDist = sqrt((dx * dx) / (radiusX * radiusX) + (dy * dy) / (radiusY * radiusY))
        let edgeDistance = abs(normalizedDist - 1.0) * min(radiusX, radiusY)

        return edgeDistance <= radius
    }

    private func textIntersectsPoint(_ text: TextAnnotation, point: NSPoint, radius: CGFloat) -> Bool {
        let textRect = getTextRect(for: text)
        let expandedRect = textRect.insetBy(dx: -radius, dy: -radius)
        return expandedRect.contains(point)
    }

    private func counterIntersectsPoint(_ counter: CounterAnnotation, point: NSPoint, radius: CGFloat) -> Bool {
        let counterRadius = counter.radius
        let dx = point.x - counter.position.x
        let dy = point.y - counter.position.y
        let distance = sqrt(dx * dx + dy * dy)
        return distance <= (counterRadius + radius)
    }
}
