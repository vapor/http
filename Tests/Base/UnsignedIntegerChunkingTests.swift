import Foundation
import XCTest

@testable import Base


class UnsignedIntegerChunkingTests: XCTestCase {
    static var allTests: [(String, (UnsignedIntegerChunkingTests) -> () throws -> Void)] {
        return [
            ("testUIntChunking8", testUIntChunking8),
            ("testUIntChunking16", testUIntChunking16),
            ("testUIntChunking32", testUIntChunking32),
            ("testUIntChunking64", testUIntChunking64),
            ("testByteArrayToUInt", testByteArrayToUInt),
            ("testHex", testHex)
        ]
    }

    func testUIntChunking8() {
        let value: UInt8 = 0x1A
        let bytes = value.bytes()
        XCTAssert(bytes == [0x1A])
        XCTAssert(UInt8(bytes) == value)
    }

    func testUIntChunking16() {
        let value: UInt16 = 0x1A_2B
        let bytes = value.bytes()
        XCTAssert(bytes == [0x1A, 0x2B])
        XCTAssert(UInt16(bytes) == value)
    }
    func testUIntChunking32() {
        let value: UInt32 = 0x1A_2B_3C_4E
        let bytes = value.bytes()
        XCTAssert(bytes == [0x1A, 0x2B, 0x3C, 0x4E])
        XCTAssert(UInt32(bytes) == value)
    }

    func testUIntChunking64() {
        let value: UInt64 = 0x1A_2B_3C_4E_5F_6A_7B_8C
        let bytes = value.bytes()
        XCTAssert(bytes == [0x1A, 0x2B, 0x3C, 0x4E, 0x5F, 0x6A, 0x7B, 0x8C])
        XCTAssert(UInt64(bytes) == value)
    }

    func testByteArrayToUInt() {
        func expect<U: UnsignedInteger>(_ bytes: Byte..., equalTo expected: U) {
            let received = U.init(bytes)
            XCTAssert(expected == received)
        }

        expect(0x01, 0x00, equalTo: UInt16(0x01_00))
        expect(0x01, 0x00, equalTo: UInt32(0x01_00))
        expect(0x01, 0x00, equalTo: UInt64(0x01_00))

        expect(0x11, 0x10, 0xA0, 0x01, equalTo: UInt32(0x11_10_A0_01))
        expect(0x11, 0x10, 0xA0, 0x01, equalTo: UInt64(0x11_10_A0_01))

        expect(0x0A, 0xFF, 0x00, 0x54, 0xAA, 0xAB, 0xDE, 0xCC,
               equalTo: UInt64(0x0A_FF_00_54_AA_AB_DE_CC))
    }

    func testHex() {
        // 1, 0 => 16 in hex
        let hexIntegerBytes: Bytes = [0x31, 0x30]
        let sixteen = hexIntegerBytes.hexInt
        XCTAssert(sixteen == 16)
    }
}
