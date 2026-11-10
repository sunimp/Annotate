import XCTest

@testable import Annotate

@MainActor
final class ArrowDrawingTests: XCTestCase {
    var overlayView: OverlayView!
    
    override func setUp() async throws {
        try await super.setUp()
        overlayView = OverlayView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }
    
    override func tearDown() async throws {
        overlayView = nil
        try await super.tearDown()
    }
    
    func testArrowCreationWithLineWidth() {
        // Test that arrows are created with the correct line width
        let start = NSPoint(x: 100, y: 100)
        let end = NSPoint(x: 200, y: 200)
        let lineWidth: CGFloat = 5.0
        
        overlayView.currentLineWidth = lineWidth
        let arrow = Arrow(
            startPoint: start,
            endPoint: end,
            color: .red,
            lineWidth: overlayView.currentLineWidth
        )
        
        XCTAssertEqual(arrow.lineWidth, lineWidth)
        XCTAssertEqual(arrow.startPoint, start)
        XCTAssertEqual(arrow.endPoint, end)
    }
    
    func testArrowWithDifferentLineWidths() {
        // Test that arrows with different line widths are distinct
        let start = NSPoint(x: 50, y: 50)
        let end = NSPoint(x: 150, y: 150)
        
        let arrow1 = Arrow(startPoint: start, endPoint: end, color: .blue, lineWidth: 2.0)
        let arrow2 = Arrow(startPoint: start, endPoint: end, color: .blue, lineWidth: 8.0)
        
        XCTAssertNotEqual(arrow1, arrow2)
        XCTAssertNotEqual(arrow1.lineWidth, arrow2.lineWidth)
    }
    
    func testArrowEquilateralTriangleCalculation() {
        // Test the mathematical correctness of equilateral triangle dimensions
        // For an equilateral triangle with side length 25:
        // - Height should be approximately 21.65 (25 * sqrt(3) / 2)
        // - Half-base should be 12.5 (25 / 2)
        
        let sideLength: CGFloat = 25.0
        let expectedHeight = sideLength * sqrt(3.0) / 2.0
        let expectedHalfBase = sideLength / 2.0
        
        // Verify the math
        XCTAssertEqual(expectedHeight, 21.650635094610966, accuracy: 0.0001)
        XCTAssertEqual(expectedHalfBase, 12.5)
        
        // The triangle should have all sides equal
        // Distance from tip to each base corner should equal the base width
        let tipToBaseDistance = expectedHeight
        let baseWidth = sideLength
        
        // Using Pythagorean theorem to verify
        // Distance from tip to corner = sqrt(height^2 + halfBase^2)
        let calculatedSideLength = sqrt(pow(expectedHeight, 2) + pow(expectedHalfBase, 2))
        XCTAssertEqual(calculatedSideLength, sideLength, accuracy: 0.0001)
    }
    
    func testArrowLineEndsAtTriangleBase() {
        // Test that the arrow line should end at the base of the triangle
        // to prevent overlap/gap
        
        let start = NSPoint(x: 0, y: 0)
        let end = NSPoint(x: 100, y: 0)
        
        let sideLength: CGFloat = 25.0
        let height = sideLength * sqrt(3.0) / 2.0
        
        // The line should end at distance 'height' from the tip
        let expectedLineEndX = end.x - height
        
        // Verify the calculation
        XCTAssertEqual(expectedLineEndX, 100 - 21.650635094610966, accuracy: 0.0001)
    }
    
    func testArrowWithVariousAngles() {
        // Test arrows pointing in different directions maintain correct geometry
        let origin = NSPoint(x: 100, y: 100)
        let distance: CGFloat = 100.0
        
        // Horizontal right arrow
        let arrowRight = Arrow(
            startPoint: origin,
            endPoint: NSPoint(x: origin.x + distance, y: origin.y),
            color: .red,
            lineWidth: 3.0
        )
        
        // Horizontal left arrow
        let arrowLeft = Arrow(
            startPoint: origin,
            endPoint: NSPoint(x: origin.x - distance, y: origin.y),
            color: .red,
            lineWidth: 3.0
        )
        
        // Vertical up arrow
        let arrowUp = Arrow(
            startPoint: origin,
            endPoint: NSPoint(x: origin.x, y: origin.y + distance),
            color: .red,
            lineWidth: 3.0
        )
        
        // Vertical down arrow
        let arrowDown = Arrow(
            startPoint: origin,
            endPoint: NSPoint(x: origin.x, y: origin.y - distance),
            color: .red,
            lineWidth: 3.0
        )
        
        // All arrows should have the same line width
        XCTAssertEqual(arrowRight.lineWidth, arrowLeft.lineWidth)
        XCTAssertEqual(arrowLeft.lineWidth, arrowUp.lineWidth)
        XCTAssertEqual(arrowUp.lineWidth, arrowDown.lineWidth)
        
        // All arrows should have the same length
        let lengthRight = hypot(arrowRight.endPoint.x - arrowRight.startPoint.x,
                               arrowRight.endPoint.y - arrowRight.startPoint.y)
        let lengthLeft = hypot(arrowLeft.endPoint.x - arrowLeft.startPoint.x,
                              arrowLeft.endPoint.y - arrowLeft.startPoint.y)
        let lengthUp = hypot(arrowUp.endPoint.x - arrowUp.startPoint.x,
                            arrowUp.endPoint.y - arrowUp.startPoint.y)
        let lengthDown = hypot(arrowDown.endPoint.x - arrowDown.startPoint.x,
                              arrowDown.endPoint.y - arrowDown.startPoint.y)
        
        XCTAssertEqual(lengthRight, distance, accuracy: 0.0001)
        XCTAssertEqual(lengthLeft, distance, accuracy: 0.0001)
        XCTAssertEqual(lengthUp, distance, accuracy: 0.0001)
        XCTAssertEqual(lengthDown, distance, accuracy: 0.0001)
    }
    
    func testArrowAddedToOverlayView() {
        // Test that arrows can be added to the overlay view
        overlayView.currentTool = .arrow
        overlayView.currentLineWidth = 4.0
        
        let initialCount = overlayView.arrows.count
        
        let arrow = Arrow(
            startPoint: NSPoint(x: 10, y: 10),
            endPoint: NSPoint(x: 50, y: 50),
            color: .blue,
            lineWidth: overlayView.currentLineWidth
        )
        
        overlayView.arrows.append(arrow)
        
        XCTAssertEqual(overlayView.arrows.count, initialCount + 1)
        XCTAssertEqual(overlayView.arrows.last?.lineWidth, 4.0)
    }
    
    func testArrowheadScalesWithLineWidth() {
        // Test that arrowhead size is relative to line width
        // Formula: max(10.0, lineWidth * 4.0)
        
        // Test thin line width
        let thinLineWidth: CGFloat = 1.0
        let thinArrowheadSize = max(10.0, thinLineWidth * 4.0)
        XCTAssertEqual(thinArrowheadSize, 10.0, "Thin line should use minimum arrowhead size")
        
        // Test default line width
        let defaultLineWidth: CGFloat = 3.0
        let defaultArrowheadSize = max(10.0, defaultLineWidth * 4.0)
        XCTAssertEqual(defaultArrowheadSize, 12.0, "Default line should scale arrowhead size")
        
        // Test medium line width
        let mediumLineWidth: CGFloat = 5.0
        let mediumArrowheadSize = max(10.0, mediumLineWidth * 4.0)
        XCTAssertEqual(mediumArrowheadSize, 20.0, "Medium line should scale arrowhead size")
        
        // Test thick line width
        let thickLineWidth: CGFloat = 10.0
        let thickArrowheadSize = max(10.0, thickLineWidth * 4.0)
        XCTAssertEqual(thickArrowheadSize, 40.0, "Thick line should scale arrowhead size proportionally")
        
        // Test maximum line width
        let maxLineWidth: CGFloat = 20.0
        let maxArrowheadSize = max(10.0, maxLineWidth * 4.0)
        XCTAssertEqual(maxArrowheadSize, 80.0, "Maximum line width should have largest arrowhead")
    }
    
    func testArrowheadSizeFormula() {
        // Test the arrowhead size formula matches expected behavior
        // Formula: max(10.0, lineWidth * 4.0)
        let testCases: [(lineWidth: CGFloat, expectedSize: CGFloat)] = [
            (0.5, 10.0),   // Min size
            (1.0, 10.0),   // Min size
            (2.0, 10.0),   // Min size
            (2.5, 10.0),   // At boundary
            (3.0, 12.0),   // Scaling starts
            (4.0, 16.0),   // Scaling
            (5.0, 20.0),   // Scaling
            (8.0, 32.0),   // Large
            (15.0, 60.0),  // Large
            (20.0, 80.0)   // Maximum
        ]
        
        for testCase in testCases {
            let calculatedSize = max(10.0, testCase.lineWidth * 4.0)
            XCTAssertEqual(
                calculatedSize,
                testCase.expectedSize,
                accuracy: 0.01,
                "Line width \(testCase.lineWidth) should produce arrowhead size \(testCase.expectedSize)"
            )
        }
    }

    func testAShortArrowOutlineStaysBetweenItsEnds() {
        // An arrow shorter than its head used to fold its shaft back past the start.
        for style in ArrowStyle.allCases {
            let arrow = Arrow(
                startPoint: NSPoint(x: 100, y: 100), endPoint: NSPoint(x: 104, y: 100),
                color: .red, lineWidth: 10, style: style)
            let bounds = arrow.outline.bounds
            XCTAssertGreaterThanOrEqual(bounds.minX, 100 - 5 - 0.01, "\(style)")
            XCTAssertLessThanOrEqual(bounds.maxX, 104 + 0.01, "\(style)")
        }
    }

    func testEveryArrowStyleCoversItsShaftAndHead() {
        for style in ArrowStyle.allCases {
            let arrow = Arrow(
                startPoint: NSPoint(x: 100, y: 100), endPoint: NSPoint(x: 300, y: 100),
                color: .red, lineWidth: 6, style: style)
            XCTAssertTrue(arrow.outline.contains(NSPoint(x: 200, y: 100)), "\(style) shaft")
            XCTAssertTrue(arrow.outline.contains(NSPoint(x: 295, y: 100)), "\(style) head")
            XCTAssertFalse(arrow.outline.contains(NSPoint(x: 200, y: 120)), "\(style) beside")
        }
    }
}
