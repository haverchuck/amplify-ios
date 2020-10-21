//
// Copyright 2018-2020 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import AWSMobileClient
import AWSPluginsCore
@testable import AWSAPICategoryPlugin
@testable import Amplify
@testable import AmplifyTestCommon
@testable import AWSAPICategoryPluginTestCommon

extension GraphQLModelBasedTests {

    /// Test paginated list query returns a List containing pagination functionality. This test also aggregates page
    /// results by appending to an in-memory Array, useful to backing UI components which.
    ///
    /// - Given: Two posts, and a query with the predicate for the two posts and a limit of 1
    /// - When:
    ///    - first query returns a List that provides Paginatable methods, and contains next page.
    ///    - subsequent queries exhaust the results from the API to retrieve the remaining results
    /// - Then:
    ///    - the in-memory Array is a populated with all expected items.
    func testPaginatedListGetNextPageAsync() throws {
        let uuid1 = UUID().uuidString
        let uuid2 = UUID().uuidString
        let testMethodName = String("\(#function)".dropLast(2))
        let title = testMethodName + "Title"
        guard createPost(id: uuid1, title: title) != nil,
              createPost(id: uuid2, title: title) != nil else {
            XCTFail("Failed to ensure at least two Posts to be retrieved on the listQuery")
            return
        }

        let firstQueryCompleted = expectation(description: "first query completed")
        let post = Post.keys
        let predicate = post.id == uuid1 || post.id == uuid2
        var results: List<Post>?
        _ = Amplify.API.query(request: .paginatedList(Post.self, where: predicate, limit: 1)) { event in
            switch event {
            case .success(let response):
                guard case let .success(graphQLResponse) = response else {
                    XCTFail("Missing successful response")
                    return
                }

                results = graphQLResponse
                firstQueryCompleted.fulfill()
            case .failure(let error):
                XCTFail("Unexpected .failure event: \(error)")
            }
        }

        wait(for: [firstQueryCompleted], timeout: TestCommonConstants.networkTimeout)
        XCTAssertNotNil(results)
        let secondQueryCompleted = expectation(description: "first query completed")
        if results!.hasNextPage() {
            results!.getNextPage { result in
                switch result {
                case .success(let list):
                    XCTAssertNotNil(list)
                    secondQueryCompleted.fulfill()
                case .failure(let error):
                    XCTFail("Failed to get next page \(error)")
                }
            }
        }
        wait(for: [secondQueryCompleted], timeout: TestCommonConstants.networkTimeout)
    }

    /// Test paginated list query returns a List containing pagination functionality. This test also aggregates page
    /// results by appending to an in-memory Array, useful to backing UI components which.
    ///
    /// - Given: Two posts, and a query with the predicate for the two posts and a limit of 1
    /// - When:
    ///    - first query returns a List that provides Paginatable methods, and contains next page.
    ///    - subsequent queries exhaust the results from the API to retrieve the remaining results
    /// - Then:
    ///    - the in-memory Array is a populated with all expected items.
    func testPaginatedListGetNextPageSync() throws {
        var resultsArray: [Post] = []
        let uuid1 = UUID().uuidString
        let uuid2 = UUID().uuidString
        let testMethodName = String("\(#function)".dropLast(2))
        let title = testMethodName + "Title"
        guard createPost(id: uuid1, title: title) != nil,
              createPost(id: uuid2, title: title) != nil else {
            XCTFail("Failed to ensure at least two Posts to be retrieved on the listQuery")
            return
        }

        let firstQueryCompleted = expectation(description: "first query completed")
        let post = Post.keys
        let predicate = post.id == uuid1 || post.id == uuid2
        var results: List<Post>?
        _ = Amplify.API.query(request: .paginatedList(Post.self, where: predicate, limit: 1)) { event in
            switch event {
            case .success(let response):
                guard case let .success(graphQLResponse) = response else {
                    XCTFail("Missing successful response")
                    return
                }

                results = graphQLResponse
                firstQueryCompleted.fulfill()
            case .failure(let error):
                XCTFail("Unexpected .failure event: \(error)")
            }
        }

        wait(for: [firstQueryCompleted], timeout: TestCommonConstants.networkTimeout)
        guard var subsequentResults = results else {
            XCTFail("Could not get first results")
            return
        }

        resultsArray.append(contentsOf: subsequentResults)

        while subsequentResults.hasNextPage() {
            subsequentResults = try subsequentResults.getNextPage()
            resultsArray.append(contentsOf: subsequentResults)
        }
        XCTAssertEqual(resultsArray.count, 2)
    }
}
