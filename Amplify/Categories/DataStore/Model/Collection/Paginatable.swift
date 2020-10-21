//
// Copyright 2018-2020 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Provides paging related functionality
public protocol Paginatable {

    typealias PageResultCallback = (Result<Page, Error>) -> Void
    associatedtype Page

    /// Checks if there is subsequent data to retrieve. If True, retrieve the next page using `getNextPage()`
    func hasNextPage() -> Bool

    /// Retrieves the next page as a new in-memory object synchronously.
    func getNextPage() throws -> Page

    /// Retrieves the next page as a new in-memory object asynchronously.
    func getNextPage(completion: @escaping PageResultCallback)
}
