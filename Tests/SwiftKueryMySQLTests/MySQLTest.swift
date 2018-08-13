/**
 * Copyright IBM Corporation 2017
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import XCTest
import Dispatch
import Foundation

import SwiftKuery
import SwiftKueryMySQL

protocol Test {
    func expectation(_ index: Int) -> XCTestExpectation
    func waitExpectation(timeout t: TimeInterval, handler: XCWaitCompletionHandler?)
}

extension Test {

    func doSetUp() {
    }

    func doTearDown() {
        // sleep(10)
    }

    func performTest(asyncTasks: (XCTestExpectation) -> Void...) {
        let queue = DispatchQueue(label: "Query queue")

        for (index, asyncTask) in asyncTasks.enumerated() {
            let expectation = self.expectation(index)
            queue.async() {
                asyncTask(expectation)
            }
        }

        waitExpectation(timeout: 30) { error in
            // blocks test until request completes
            XCTAssertNil(error)
        }
    }
}

extension XCTestCase: Test {
    func expectation(_ index: Int) -> XCTestExpectation {
        let expectationDescription = "\(type(of: self))-\(index)"
        return self.expectation(description: expectationDescription)
    }

    func waitExpectation(timeout t: TimeInterval, handler: XCWaitCompletionHandler?) {
        self.waitForExpectations(timeout: t, handler: handler)
    }
}

/*class MySQLTest: XCTestCase {
    private static var threadSafePool: ConnectionPool?
    private static var threadUnsafePool: ConnectionPool?

    func performTest(characterSet: String? = nil, timeout: TimeInterval = 10, line: Int = #line, asyncTasks: (Connection) -> Void...) {

        var connection: Connection
        guard let pool = getPool(taskCount: asyncTasks.count, characterSet: characterSet).pool else {
            XCTFail("Failed to get connection pool")
            return
        }

        guard let conn = pool.getConnection() else {
            XCTFail("Failed to get connection")
            return
        }
        connection = conn

        defer {
            connection.closeConnection()
        }

        var connectError: QueryError? = nil
        connection.connect() { error in
            if let error = error {
                connectError = error
                return
            }

            // use a concurrent queue so we can test connection is thread-safe
            let queue = DispatchQueue(label: "Test tasks queue", attributes: .concurrent)
            queue.suspend() // don't start executing tasks when queued

            for (index, asyncTask) in asyncTasks.enumerated() {
                let exp = self.expectation(description: "\(type(of: self)):\(line)[\(index)]")
                queue.async() {
                    asyncTask(connection)
                    exp.fulfill()
                }
            }

            queue.resume() // all tasks are queued, execute them
        }

        if let error = connectError {
            XCTFail(error.description)
        } else {
            // wait for all async tasks to finish
            waitForExpectations(timeout: timeout) { error in
                XCTAssertNil(error)
            }
        }
    }

    private func getPool(taskCount: Int, characterSet: String?) -> (connection: Connection?, pool: ConnectionPool?) {
        if characterSet == nil {
            if let pool = (taskCount > 1 ? MySQLTest.threadSafePool : MySQLTest.threadUnsafePool) {
                return (nil, pool)
            }
        }

        let pool: ConnectionPool?
        do {
            let connectionFile = #file.replacingOccurrences(of: "MySQLTest.swift", with: "connection.json")
            let data = Data(referencing: try NSData(contentsOfFile: connectionFile))
            let json = try JSONSerialization.jsonObject(with: data)

            if let dictionary = json as? [String: String] {
                let host = dictionary["host"]
                let username = dictionary["username"]
                let password = dictionary["password"]
                let database = dictionary["database"]
                var port: Int? = nil
                if let portString = dictionary["port"] {
                    port = Int(portString)
                }

                let randomBinary: UInt32
                #if os(Linux)
                    randomBinary = UInt32(random() % 2)
                #else
                    randomBinary = arc4random_uniform(2)
                #endif

                let poolOptions = ConnectionPoolOptions(initialCapacity: 1, maxCapacity: 1, timeout: 10000)

                if characterSet != nil || randomBinary == 0 {
                    if taskCount > 1 {
                        pool = MySQLThreadSafeConnection.createPool(host: host, user: username, password: password, database: database, port: port, characterSet: characterSet, poolOptions: poolOptions)
                    } else {
                        pool = MySQLConnection.createPool(host: host, user: username, password: password, database: database, port: port, characterSet: characterSet, poolOptions: poolOptions)
                    }
                } else {
                    var urlString = "mysql://"
                    if let username = username, let password = password {
                        urlString += "\(username):\(password)@"
                    }
                    urlString += host ?? "localhost"
                    if let port = port {
                        urlString += ":\(port)"
                    }
                    if let database = database {
                        urlString += "/\(database)"
                    }

                    if let url = URL(string: urlString) {
                        if taskCount > 1 {
                            pool = MySQLThreadSafeConnection.createPool(url: url, poolOptions: poolOptions)
                        } else {
                            pool = MySQLConnection.createPool(url: url, poolOptions: poolOptions)
                        }
                    } else {
                        pool = nil
                        XCTFail("Invalid URL format: \(urlString)")
                    }
                }
            } else {
                pool = nil
                XCTFail("Invalid format for connection.json contents: \(json)")
            }
        } catch {
            pool = nil
            XCTFail(error.localizedDescription)
        }

        if taskCount > 1 {
            MySQLTest.threadSafePool = pool
        } else {
            MySQLTest.threadUnsafePool = pool
        }

        return (nil, pool)
    }
}*/
