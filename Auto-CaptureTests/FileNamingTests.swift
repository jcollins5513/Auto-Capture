import XCTest
@testable import Auto_Capture

final class FileNamingTests: XCTestCase {
    
    // MARK: - File Naming Convention Tests
    
    func testPhotoFilenameFormat() {
        // Given
        let sessionId = UUID()
        let stockNumber = "ABC123"
        let order = 1
        let viewpoint = Viewpoint.frontDriver3rd
        let timestamp = Date(timeIntervalSince1970: 1706348222) // 2025-01-27 14:37:02
        
        // When
        let filename = generatePhotoFilename(
            order: order,
            viewpoint: viewpoint,
            timestamp: timestamp
        )
        
        // Then
        XCTAssertEqual(filename, "01_FRONT_DRIVER_3RD_20250127-143702.jpg")
    }
    
    func testAllViewpointFilenames() {
        let viewpoints: [(Viewpoint, String)] = [
            (.frontDriver3rd, "FRONT_DRIVER_3RD"),
            (.front, "FRONT"),
            (.frontPassenger3rd, "FRONT_PASSENGER_3RD"),
            (.sidePassenger, "SIDE_PASSENGER"),
            (.backPassenger3rd, "BACK_PASSENGER_3RD"),
            (.back, "BACK"),
            (.backDriver3rd, "BACK_DRIVER_3RD"),
            (.sideDriver, "SIDE_DRIVER")
        ]
        
        let timestamp = Date(timeIntervalSince1970: 1706348222)
        
        for (index, (viewpoint, expectedSuffix)) in viewpoints.enumerated() {
            let order = index + 1
            let filename = generatePhotoFilename(
                order: order,
                viewpoint: viewpoint,
                timestamp: timestamp
            )
            
            let expectedFilename = String(format: "%02d_%@_20250127-143702.jpg", order, expectedSuffix)
            XCTAssertEqual(filename, expectedFilename, "Filename for \(viewpoint) should match expected format")
        }
    }
    
    func testSessionFolderNaming() {
        // Given
        let stockNumber = "ABC123"
        let timestamp = Date(timeIntervalSince1970: 1706348222) // 2025-01-27 14:37:02
        let sessionId = UUID()
        
        // When
        let folderName = generateSessionFolderName(
            stockNumber: stockNumber,
            timestamp: timestamp
        )
        
        // Then
        XCTAssertEqual(folderName, "ABC123-20250127-143702")
    }
    
    func testStockNumberValidation() {
        // Valid stock numbers
        let validStockNumbers = [
            "ABC123",
            "XYZ789",
            "CAR001",
            "TEST123456789",
            "A1B2C3"
        ]
        
        for stockNumber in validStockNumbers {
            XCTAssertTrue(isValidStockNumber(stockNumber), "\(stockNumber) should be valid")
        }
        
        // Invalid stock numbers
        let invalidStockNumbers = [
            "", // Empty
            "AB", // Too short
            "ABC12345678901234567890", // Too long
            "ABC-123", // Contains hyphen
            "ABC 123", // Contains space
            "ABC@123", // Contains special character
            "123ABC", // Starts with number (if that's not allowed)
        ]
        
        for stockNumber in invalidStockNumbers {
            XCTAssertFalse(isValidStockNumber(stockNumber), "\(stockNumber) should be invalid")
        }
    }
    
    func testOrderNumberFormatting() {
        // Test order number formatting with leading zeros
        let orders = [1, 2, 3, 4, 5, 6, 7, 8]
        let expectedFormats = ["01", "02", "03", "04", "05", "06", "07", "08"]
        
        for (order, expected) in zip(orders, expectedFormats) {
            let formatted = String(format: "%02d", order)
            XCTAssertEqual(formatted, expected)
        }
    }
    
    func testTimestampFormatting() {
        // Given
        let timestamp = Date(timeIntervalSince1970: 1706348222) // 2025-01-27 14:37:02
        
        // When
        let formatted = formatTimestamp(timestamp)
        
        // Then
        XCTAssertEqual(formatted, "20250127-143702")
    }
    
    func testFilenameUniqueness() {
        // Given
        let stockNumber = "ABC123"
        let timestamp1 = Date(timeIntervalSince1970: 1706348222)
        let timestamp2 = Date(timeIntervalSince1970: 1706348223) // 1 second later
        
        // When
        let filename1 = generateSessionFolderName(stockNumber: stockNumber, timestamp: timestamp1)
        let filename2 = generateSessionFolderName(stockNumber: stockNumber, timestamp: timestamp2)
        
        // Then
        XCTAssertNotEqual(filename1, filename2, "Filenames should be unique for different timestamps")
    }
    
    func testSpecialCharactersHandling() {
        // Given
        let stockNumber = "ABC123"
        let viewpoint = Viewpoint.frontDriver3rd
        let timestamp = Date(timeIntervalSince1970: 1706348222)
        
        // When
        let filename = generatePhotoFilename(
            order: 1,
            viewpoint: viewpoint,
            timestamp: timestamp
        )
        
        // Then
        // Should not contain any characters that would be problematic in filenames
        let invalidChars = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
        for char in invalidChars {
            XCTAssertFalse(filename.contains(char), "Filename should not contain \(char)")
        }
    }
    
    func testRetakeFilenameFormat() {
        // Given
        let originalPhoto = PhotoCapture(
            id: UUID(),
            sessionId: UUID(),
            viewpoint: .frontDriver3rd,
            order: 1,
            capturedAt: Date(timeIntervalSince1970: 1706348222),
            filePath: "01_FRONT_DRIVER_3RD_20250127-143702.jpg",
            confidence: 0.95,
            isRetake: false,
            originalPhotoId: nil,
            exifData: createMockEXIFData()
        )
        
        let retakeTimestamp = Date(timeIntervalSince1970: 1706348322) // 100 seconds later
        
        // When
        let retakeFilename = generateRetakeFilename(
            for: originalPhoto,
            retakeTimestamp: retakeTimestamp
        )
        
        // Then
        XCTAssertTrue(retakeFilename.contains("01_FRONT_DRIVER_3RD"))
        XCTAssertTrue(retakeFilename.contains("20250127-143802")) // Different timestamp
        XCTAssertTrue(retakeFilename.hasSuffix(".jpg"))
    }
    
    // MARK: - Helper Methods (These will be implemented in the actual utility)
    
    private func generatePhotoFilename(order: Int, viewpoint: Viewpoint, timestamp: Date) -> String {
        // This will fail until implementation
        XCTFail("generatePhotoFilename not implemented - test will fail")
        return ""
    }
    
    private func generateSessionFolderName(stockNumber: String, timestamp: Date) -> String {
        // This will fail until implementation
        XCTFail("generateSessionFolderName not implemented - test will fail")
        return ""
    }
    
    private func isValidStockNumber(_ stockNumber: String) -> Bool {
        // This will fail until implementation
        XCTFail("isValidStockNumber not implemented - test will fail")
        return false
    }
    
    private func formatTimestamp(_ timestamp: Date) -> String {
        // This will fail until implementation
        XCTFail("formatTimestamp not implemented - test will fail")
        return ""
    }
    
    private func generateRetakeFilename(for originalPhoto: PhotoCapture, retakeTimestamp: Date) -> String {
        // This will fail until implementation
        XCTFail("generateRetakeFilename not implemented - test will fail")
        return ""
    }
    
    private func createMockEXIFData() -> EXIFData {
        return EXIFData(
            stockNumber: "TEST123",
            viewpoint: "FRONT_DRIVER_3RD",
            sessionId: UUID().uuidString,
            appVersion: "1.0.0",
            captureTimestamp: Date(),
            deviceModel: "iPhone 15 Pro",
            iosVersion: "17.0",
            cameraSettings: nil
        )
    }
}
