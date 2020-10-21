//
// Copyright 2018-2020 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Amplify
import AWSPluginsCore

extension AppSyncList {
    func reconstructGraphQLRequestForNextPage(nextToken: String) -> GraphQLRequest<AppSyncList<ModelType>> {
        var documentBuilder = ModelBasedGraphQLDocumentBuilder(modelType: ModelType.self, operationType: .query)
        documentBuilder.add(decorator: DirectiveNameDecorator(type: .list))

        // Since the original request constructed with `QueryPredicate` is lost when translated to a GraphQLRequest
        // The following extracts the existing filter variables stored in the GraphQLRequest's variables
        // and uses FilterDecorator to re-create the proper document with variable input parameters
        // and variables containing the filter values.
        if let storedVariables = variables,
           let filters = storedVariables["filter"],
           case let .object(filterValue) = filters {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = ModelDateFormatting.encodingStrategy
            guard let filterVariablesData = try? encoder.encode(filterValue),
                  let filterVariablesJSON = try? JSONSerialization.jsonObject(with: filterVariablesData)
                    as? [String: Any] else {
                fatalError("Filter variables is not valid JSON object")
            }
            documentBuilder.add(decorator: FilterDecorator(filter: filterVariablesJSON))
        }

        // Similar to the filter variables, limit is also stored in the variables and expected to be persisted
        // across multiple `getNextPage` calls, hence extract the limit from the variables if it exists
        if let storedVariables = variables,
           let limit = storedVariables["limit"],
           case let .number(limitValue) = limit {
            documentBuilder.add(decorator: PaginationDecorator(limit: Int(limitValue), nextToken: nextToken))
        } else {
            documentBuilder.add(decorator: PaginationDecorator(nextToken: nextToken))
        }

        let document = documentBuilder.build()
        return GraphQLRequest<AppSyncList<ModelType>>(document: document.stringValue,
                                                      variables: document.variables,
                                                      responseType: AppSyncList<ModelType>.self,
                                                      decodePath: document.name)
    }
}
