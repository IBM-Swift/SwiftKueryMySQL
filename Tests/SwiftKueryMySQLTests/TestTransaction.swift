/**
 Copyright IBM Corporation 2017

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import XCTest
import SwiftKuery

#if os(Linux)
let tableTransaction = "tableTransactionLinux"
#else
let tableTransaction = "tableTransactionOSX"
#endif

class TestTransaction: MySQLTest {

    static var allTests: [(String, (TestTransaction) -> () throws -> Void)] {
        return [
            ("testErrors", testErrors),
            ("testRollback", testRollback),
            ("testSavepoint", testSavepoint),
            ("testTransaction", testTransaction),
        ]
    }

    class MyTable : Table {
        let a = Column("a")
        let b = Column("b")

        let tableName = tableTransaction
    }

    func testTransaction() {
        performTest(asyncTasks: { connection in
            let t = MyTable()
            cleanUp(table: t.tableName, connection: connection) { _ in }

            executeRawQuery("CREATE TABLE " +  t.tableName + " (a varchar(40), b integer)", connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "CREATE TABLE failed")
                XCTAssertNil(result.asError, "Error in CREATE TABLE: \(result.asError!)")
            }

            connection.startTransaction() { result in
                XCTAssertEqual(result.success, true, "Failed to start transaction")
                XCTAssertNil(result.asError, "Error in start transaction: \(result.asError!)")
            }

            let i1 = Insert(into: t, rows: [["apple", 10], ["apricot", 3]])
            executeQuery(query: i1, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "INSERT failed")
                XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")
            }

            let i2 = Insert(into: t, rows: [["apple", 12], ["apricot", 23]])
            executeQuery(query: i2, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "INSERT failed")
                XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")
            }

            connection.commit() { result in
                XCTAssertEqual(result.success, true, "Failed to commit transaction")
                XCTAssertNil(result.asError, "Error in commit transaction: \(result.asError!)")
            }

            let s = Select(from: t)
            executeQuery(query: s, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "SELECT failed")
                XCTAssertNotNil(rows, "SELECT returned no rows")
                XCTAssertEqual(rows?.count, 4, "SELECT returned wrong number of rows: \(String(describing: rows?.count)) instead of 4")
            }
        })
    }

    func testRollback() {
        performTest(asyncTasks: { connection in
            let t = MyTable()
            cleanUp(table: t.tableName, connection: connection) { _ in }

            executeRawQuery("CREATE TABLE " +  t.tableName + " (a varchar(40), b integer)", connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "CREATE TABLE failed")
                XCTAssertNil(result.asError, "Error in CREATE TABLE: \(result.asError!)")
            }

            connection.startTransaction() { result in
                XCTAssertEqual(result.success, true, "Failed to start transaction")
                XCTAssertNil(result.asError, "Error in start transaction: \(result.asError!)")
            }

            let i1 = Insert(into: t, rows: [["apple", 10], ["apricot", 3]])
            executeQuery(query: i1, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "INSERT failed")
                XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")
            }

            let i2 = Insert(into: t, rows: [["apple", 12], ["apricot", 23]])
            executeQuery(query: i2, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "INSERT failed")
                XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")
            }

            connection.rollback() { result in
                XCTAssertEqual(result.success, true, "Failed to rollback transaction")
                XCTAssertNil(result.asError, "Error in rollback transaction: \(result.asError!)")
            }

            let s = Select(from: t)
            executeQuery(query: s, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "SELECT failed")
                XCTAssertEqual(rows?.count, 0, "SELECT should not return any rows")
            }
        })
    }

    func testSavepoint() {
        performTest(asyncTasks: { connection in
            let t = MyTable()
            cleanUp(table: t.tableName, connection: connection) { _ in }

            executeRawQuery("CREATE TABLE " +  t.tableName + " (a varchar(40), b integer)", connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "CREATE TABLE failed")
                XCTAssertNil(result.asError, "Error in CREATE TABLE: \(result.asError!)")
            }

            connection.startTransaction() { result in
                XCTAssertEqual(result.success, true, "Failed to start transaction")
                XCTAssertNil(result.asError, "Error in start transaction: \(result.asError!)")
            }

            connection.create(savepoint: "spcreate") { result in
                XCTAssertEqual(result.success, true, "Failed to create savepoint")
                XCTAssertNil(result.asError, "Error in create savepoint: \(result.asError!)")
            }

            let i1 = Insert(into: t, rows: [["apple", 10], ["apricot", 3]])
            executeQuery(query: i1, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "INSERT failed")
                XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")
            }

            connection.create(savepoint: "spinsert1") { result in
                XCTAssertEqual(result.success, true, "Failed to create savepoint")
                XCTAssertNil(result.asError, "Error in create savepoint: \(result.asError!)")
            }

            let i2 = Insert(into: t, rows: [["apple", 12], ["apricot", 23]])
            executeQuery(query: i2, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "INSERT failed")
                XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")
            }

            connection.create(savepoint: "spinsert2") { result in
                XCTAssertEqual(result.success, true, "Failed to create savepoint")
                XCTAssertNil(result.asError, "Error in create savepoint: \(result.asError!)")
            }

            connection.release(savepoint: "spinsert2") { result in
                XCTAssertEqual(result.success, true, "Failed to release savepoint")
                XCTAssertNil(result.asError, "Error in release savepoint: \(result.asError!)")
            }

            connection.rollback(to: "spinsert1") { result in
                XCTAssertEqual(result.success, true, "Failed to rollback transaction")
                XCTAssertNil(result.asError, "Error in rollback transaction: \(result.asError!)")
            }

            var s = Select(from: t)
            executeQuery(query: s, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "SELECT failed")
                XCTAssertNotNil(rows, "SELECT returned no rows")
                XCTAssertEqual(rows?.count, 2, "SELECT returned wrong number of rows: \(String(describing: rows?.count)) instead of 2")
            }

            connection.rollback(to: "spcreate") { result in
                XCTAssertEqual(result.success, true, "Failed to rollback transaction")
                XCTAssertNil(result.asError, "Error in rollback transaction: \(result.asError!)")
            }

            s = Select(from: t)
            executeQuery(query: s, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "SELECT failed")
                XCTAssertEqual(rows?.count, 0, "SELECT should not return any rows")
            }

            connection.release(savepoint: "spcreate") { result in
                XCTAssertEqual(result.success, true, "Failed to release savepoint")
                XCTAssertNil(result.asError, "Error in release savepoint: \(result.asError!)")
            }

            connection.commit() { result in
                XCTAssertEqual(result.success, true, "Failed to commit transaction")
                XCTAssertNil(result.asError, "Error in commit transaction: \(result.asError!)")
            }
        })
    }

    func testErrors() {
        performTest(asyncTasks: { connection in
            let t = MyTable()
            cleanUp(table: t.tableName, connection: connection) { result in

                connection.release(savepoint: "spinsert2") { result in
                    XCTAssertEqual(result.success, false, "Succeeded to release savepoint without transaction")
                }

                connection.rollback(to: "spinsert1") { result in
                    XCTAssertEqual(result.success, false, "Succeeded to rollback to savepoint without transaction")
                }

                connection.startTransaction() { result in
                    XCTAssertEqual(result.success, true, "Failed to start transaction")
                    XCTAssertNil(result.asError, "Error in start transaction: \(result.asError!)")
                }

                connection.startTransaction() { result in
                    XCTAssertEqual(result.success, false, "Started second transaction")
                }

                executeRawQuery("CREATE TABLE " +  t.tableName + " (a varchar(40), b integer)", connection: connection) { result, rows in
                    XCTAssertEqual(result.success, true, "CREATE TABLE failed")
                    XCTAssertNil(result.asError, "Error in CREATE TABLE: \(result.asError!)")
                }

                connection.create(savepoint: "spcreate") { result in
                    XCTAssertEqual(result.success, true, "Failed to create savepoint")
                    XCTAssertNil(result.asError, "Error in create savepoint: \(result.asError!)")
                }

                let i1 = Insert(into: t, rows: [["apple", 10], ["apricot", 3]])
                executeQuery(query: i1, connection: connection) { result, rows in
                    XCTAssertEqual(result.success, true, "INSERT failed")
                    XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")
                }

                connection.release(savepoint: "spinsert2") { result in
                    XCTAssertEqual(result.success, false, "Release non-existing savepoint")
                }

                connection.commit() { result in
                    XCTAssertEqual(result.success, true, "Failed to commit transaction")
                    XCTAssertNil(result.asError, "Error in commit transaction: \(result.asError!)")
                }
            }
        }, { connection in
            let t = MyTable()
            cleanUp(table: t.tableName, connection: connection) { result in

                connection.commit() { result in
                    XCTAssertEqual(result.success, false, "Succeeded to commit savepoint without transaction")
                }

                connection.create(savepoint: "spcreate") { result in
                    XCTAssertEqual(result.success, false, "Succeeded to create savepoint without transaction")
                }

                connection.startTransaction() { result in
                    XCTAssertEqual(result.success, true, "Failed to start transaction")
                    XCTAssertNil(result.asError, "Error in start transaction: \(result.asError!)")
                }

                executeRawQuery("CREATE TABLE " +  t.tableName + " (a varchar(40), b integer)", connection: connection) { result, rows in
                    XCTAssertEqual(result.success, true, "CREATE TABLE failed")
                    XCTAssertNil(result.asError, "Error in CREATE TABLE: \(result.asError!)")
                }

                connection.create(savepoint: "spcreate") { result in
                    XCTAssertEqual(result.success, true, "Failed to create savepoint")
                    XCTAssertNil(result.asError, "Error in create savepoint: \(result.asError!)")
                }

                let i1 = Insert(into: t, rows: [["apple", 10], ["apricot", 3]])
                executeQuery(query: i1, connection: connection) { result, rows in
                    XCTAssertEqual(result.success, true, "INSERT failed")
                    XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")
                }

                connection.rollback(to: "spinsert1") { result in
                    XCTAssertEqual(result.success, false, "Rolled back to non-existing savepoint")
                }

                connection.commit() { result in
                    XCTAssertEqual(result.success, true, "Failed to commit transaction")
                    XCTAssertNil(result.asError, "Error in commit transaction: \(result.asError!)")
                }
            }
        }, { connection in
            let t = MyTable()
            cleanUp(table: t.tableName, connection: connection) { result in

                connection.commit() { result in
                    XCTAssertEqual(result.success, false, "Succeeded to commit savepoint without transaction")
                }

                connection.create(savepoint: "spcreate") { result in
                    XCTAssertEqual(result.success, false, "Succeeded to create savepoint without transaction")
                }

                executeRawQuery("CREATE TABLE " +  t.tableName + " (a varchar(40), b integer)", connection: connection) { result, rows in
                    XCTAssertEqual(result.success, true, "CREATE TABLE failed")
                    XCTAssertNil(result.asError, "Error in CREATE TABLE: \(result.asError!)")
                }

                connection.startTransaction() { result in
                    XCTAssertEqual(result.success, true, "Failed to start transaction")
                    XCTAssertNil(result.asError, "Error in start transaction: \(result.asError!)")
                }

                connection.create(savepoint: "spcreate") { result in
                    XCTAssertEqual(result.success, true, "Failed to create savepoint")
                    XCTAssertNil(result.asError, "Error in create savepoint: \(result.asError!)")
                }

                let i1 = Insert(into: t, rows: [["apple", 10], ["apricot", 3]])
                executeQuery(query: i1, connection: connection) { result, rows in
                    XCTAssertEqual(result.success, true, "INSERT failed")
                    XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")
                }
                
                connection.release(savepoint: "spcreate") { result in
                    XCTAssertEqual(result.success, true, "Failed to release savepoint")
                    XCTAssertNil(result.asError, "Error in release savepoint: \(result.asError!)")
                }
                
                connection.rollback(to: "spcreate") { result in
                    XCTAssertEqual(result.success, false, "Rolled back to released savepoint")
                }
                
                connection.commit() { result in
                    XCTAssertEqual(result.success, true, "Failed to commit transaction")
                    XCTAssertNil(result.asError, "Error in commit transaction: \(result.asError!)")
                }
            }
        })
    }
}
