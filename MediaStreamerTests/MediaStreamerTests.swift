//
//  MediaStreamerTests.swift
//  MediaStreamerTests
//
//  Created by Matt Weiss on 1/20/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import XCTest
@testable import MediaStreamer

class MediaStreamerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}

class RoomTests: XCTestCase {
    
    var room:Room!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        room = Room(roomController: RoomController(), id: 111111, name: "Test")
        
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        room = nil
        super.tearDown()
    }
    
    func testAddUserNew() {
        let result = self.room.addUser(sid: "test", name: "User1")
        XCTAssertTrue(result!)
    }
    
    func testAddUserDuplicate() {
        let t = self.room.addUser(sid: "user1", name: "user1")
        let result = self.room.addUser(sid: "user1", name: "user1")
        XCTAssertTrue(t!)
        XCTAssertFalse(result!)
    }
    
    func testAddUserDuplicateName() {
        let t = self.room.addUser(sid: "user1", name: "user1")
        let result = self.room.addUser(sid: "user2", name: "user1")
        XCTAssertTrue(t!)
        XCTAssertTrue(result!)
    }
    
    func testRemoveUserExists() {
        let t = self.room.addUser(sid: "user1", name: "user1")
        let result = self.room.removeUser(sid: "user1")
        XCTAssertTrue(t!)
        XCTAssertTrue(result!)
    }
    
    func testRemoveUserDoesNotExist() {
        let result = self.room.removeUser(sid: "user1")
        XCTAssertFalse(result!)
    }
    
    func testRemoveUserDuplicateName() {
        let t1 = self.room.addUser(sid: "user1", name: "user1")
        let t2 = self.room.addUser(sid: "user2", name: "user1")
        let result1 = self.room.removeUser(sid: "user1")
        let result2 = self.room.removeUser(sid: "user2")
        XCTAssertTrue(t1!)
        XCTAssertTrue(t2!)
        XCTAssertTrue(result1!)
        XCTAssertTrue(result2!)
    }
    
    func testGetUserExists() {
        let t = self.room.addUser(sid: "sid", name: "user")
        let user = self.room.getUser(index: 0)
        XCTAssertTrue(t!)
        XCTAssertTrue(user?.0 == "sid")
        XCTAssertTrue(user?.1 == "user")
    }
    
    func testGetUserDoesNotExist() {
        let user = self.room.getUser(index: 0)
        XCTAssertTrue(user == nil)
    }
    
    func testNumUsers() {
        XCTAssertTrue(self.room.numUsers() == 0)
        let t = self.room.addUser(sid: "sid", name: "user")
        XCTAssertTrue(t!)
        XCTAssertTrue(self.room.numUsers() == 1)
    }
    
    func testClearUsers() {
        let t = self.room.addUser(sid: "sid", name: "user")
        XCTAssertTrue(t!)
        XCTAssertTrue(self.room.numUsers() == 1)
        self.room.clearUsers()
        XCTAssertTrue(self.room.numUsers() == 0)
    }
}
