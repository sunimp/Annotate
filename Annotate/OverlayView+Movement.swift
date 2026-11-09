//
//  OverlayView+Movement.swift
//  Annotate
//
//  Created by Sun on 2026/11/9.
//

import Cocoa

extension OverlayView {
    // MARK: - Object Movement
    
    /// Whether the selection includes a pixelate or blur redaction, which previews live
    /// while it is dragged.
    var selectionHasSampledRedaction: Bool {
        selectedObjects.contains {
            guard case .rectangle(let index) = $0, index < rectangles.count else { return false }
            return rectangles[index].needsSample
        }
    }

    func moveSelectedObjects(by delta: NSPoint) {
        for selectedObj in selectedObjects {
            moveObject(selectedObj, by: delta)
        }
    }
    
    private func moveObject(_ object: SelectedObject, by delta: NSPoint) {
        switch object {
        case .arrow(let index):
            guard index < arrows.count else { return }
            arrows[index].startPoint.x += delta.x
            arrows[index].startPoint.y += delta.y
            arrows[index].endPoint.x += delta.x
            arrows[index].endPoint.y += delta.y
            
        case .line(let index):
            guard index < lines.count else { return }
            lines[index].startPoint.x += delta.x
            lines[index].startPoint.y += delta.y
            lines[index].endPoint.x += delta.x
            lines[index].endPoint.y += delta.y
            
        case .rectangle(let index):
            guard index < rectangles.count else { return }
            rectangles[index].startPoint.x += delta.x
            rectangles[index].startPoint.y += delta.y
            rectangles[index].endPoint.x += delta.x
            rectangles[index].endPoint.y += delta.y
            // The sample keeps painting where it came from until the new spot's sample lands.
            
        case .circle(let index):
            guard index < circles.count else { return }
            circles[index].startPoint.x += delta.x
            circles[index].startPoint.y += delta.y
            circles[index].endPoint.x += delta.x
            circles[index].endPoint.y += delta.y
            
        case .path(let index):
            guard index < paths.count else { return }
            Self.translate(&paths[index], by: delta)
            rebuildPathGeometry(&paths[index])
            
        case .highlight(let index):
            guard index < highlightPaths.count else { return }
            Self.translate(&highlightPaths[index], by: delta)
            rebuildPathGeometry(&highlightPaths[index])
            
        case .text(let index):
            guard index < textAnnotations.count else { return }
            textAnnotations[index].position.x += delta.x
            textAnnotations[index].position.y += delta.y
            
        case .counter(let index):
            guard index < counterAnnotations.count else { return }
            counterAnnotations[index].position.x += delta.x
            counterAnnotations[index].position.y += delta.y
            
        case .none:
            break
        }
    }
    
    func getObjectPosition(_ object: SelectedObject) -> ObjectPosition? {
        switch object {
        case .arrow(let index):
            guard index < arrows.count else { return nil }
            return .endpoints(arrows[index].startPoint, arrows[index].endPoint)
        case .line(let index):
            guard index < lines.count else { return nil }
            return .endpoints(lines[index].startPoint, lines[index].endPoint)
        case .rectangle(let index):
            guard index < rectangles.count else { return nil }
            return .endpoints(rectangles[index].startPoint, rectangles[index].endPoint)
        case .circle(let index):
            guard index < circles.count else { return nil }
            return .endpoints(circles[index].startPoint, circles[index].endPoint)
        case .text(let index):
            guard index < textAnnotations.count else { return nil }
            return .point(textAnnotations[index].position)
        case .counter(let index):
            guard index < counterAnnotations.count else { return nil }
            return .point(counterAnnotations[index].position)
        case .path(let index):
            guard index < paths.count, let first = paths[index].points.first else { return nil }
            return .point(first.point)
        case .highlight(let index):
            guard index < highlightPaths.count, let first = highlightPaths[index].points.first else { return nil }
            return .point(first.point)
        case .none:
            return nil
        }
    }

    func registerMoveUndo(object: SelectedObject, from oldPos: ObjectPosition, to newPos: ObjectPosition) {
        switch (object, oldPos, newPos) {
        case let (.arrow(index), .endpoints(fromStart, fromEnd), .endpoints(toStart, toEnd)):
            registerUndo(action: .moveArrow(index, fromStart, fromEnd, toStart, toEnd))
        case let (.line(index), .endpoints(fromStart, fromEnd), .endpoints(toStart, toEnd)):
            registerUndo(action: .moveLine(index, fromStart, fromEnd, toStart, toEnd))
        case let (.rectangle(index), .endpoints(fromStart, fromEnd), .endpoints(toStart, toEnd)):
            registerUndo(action: .moveRectangle(index, fromStart, fromEnd, toStart, toEnd))
        case let (.circle(index), .endpoints(fromStart, fromEnd), .endpoints(toStart, toEnd)):
            registerUndo(action: .moveCircle(index, fromStart, fromEnd, toStart, toEnd))
        case let (.text(index), .point(from), .point(to)):
            registerUndo(action: .moveText(index, from, to))
        case let (.counter(index), .point(from), .point(to)):
            registerUndo(action: .moveCounter(index, from, to))
        case let (.path(index), .point(from), .point(to)):
            registerUndo(action: .movePath(index, from, to))
        case let (.highlight(index), .point(from), .point(to)):
            registerUndo(action: .moveHighlight(index, from, to))
        default:
            assertionFailure("Position \(oldPos) doesn't fit \(object)")
        }
    }
}
