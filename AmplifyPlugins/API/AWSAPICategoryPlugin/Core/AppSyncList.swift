//
// Copyright 2018-2020 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Amplify
import AWSPluginsCore

public class AppSyncList<ModelType: Model>: List<ModelType>, ModelListDecoder {

    public typealias Page = AppSyncList<ModelType>
    public typealias PageError = APIError

    /// The array of `Element` that backs the custom collection implementation.
    let nextToken: String?
    let document: String?
    let variables: [String: JSONValue]?

    // MARK: - Initializers

    init(_ elements: [Element],
         nextToken: String? = nil,
         document: String? = nil,
         variables: [String: JSONValue]? = nil) {
        self.nextToken = nextToken
        self.document = document
        self.variables = variables
        super.init(elements)
    }

    required convenience public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }

    // MARK: Paginatable

    public override func hasNextPage() -> Bool {
        return nextToken != nil
    }

    public override func getNextPage() throws -> Page {
        guard let nextToken = nextToken else {
            throw APIError.operationError("There is no next page to fetch.",
                                          "Check `hasNextPage()` before fetching the next page")
        }

        let request = reconstructGraphQLRequestForNextPage(nextToken: nextToken)

        let semaphore = DispatchSemaphore(value: 0)
        var resultValue: Result<AppSyncList<ModelType>, APIError>?
        Amplify.API.query(request: request) { result in
            switch result {
            case .success(let graphQLResponse):
                switch graphQLResponse {
                case .success(let list):
                    resultValue = .success(list)
                case .failure(let graphQLError):
                    resultValue = .failure(APIError(error: graphQLError))
                }
            case .failure(let apiError):
                resultValue = .failure(apiError)
            }
            semaphore.signal()
        }
        semaphore.wait()
        guard let result = resultValue else {
            throw APIError.unknown("Async operation turn sync should always set result to be returned", "")
        }
        switch result {
        case .success(let list):
            return list
        case .failure(let apiError):
            throw apiError
        }
    }

    public override func getNextPage(completion: @escaping PageResultCallback) {
        guard let nextToken = nextToken else {
            completion(.failure(APIError.operationError("There is no next page to fetch.",
                                                        "Check `hasNextPage()` before fetching the next page")))
            return
        }

        let request = reconstructGraphQLRequestForNextPage(nextToken: nextToken)

        Amplify.API.query(request: request) { result in
            switch result {
            case .success(let graphQLResponse):
                switch graphQLResponse {
                case .success(let list):
                    completion(.success(list))
                case .failure(let graphQLError):
                    completion(.failure(APIError(error: graphQLError)))
                }
            case .failure(let apiError):
                completion(.failure(apiError))
            }
        }
    }

    // MARK: ModelListDecoder

    public static func shouldDecode(decoder: Decoder) -> Bool {
        let json = try? JSONValue(from: decoder)

        if case let .object(jsonObject) = json,
           case .array = jsonObject["items"] {
            return true
        }

        do {
            _ = try AppSyncListPayload.init(from: decoder)
            return true
        } catch {
            return false
        }
    }

    public static func decode<ModelType: Model>(decoder: Decoder,
                                                modelType: ModelType.Type) -> List<ModelType> {
        do {
            return try AppSyncList<ModelType>.init(from: decoder)
        } catch {
            return List([ModelType]())
        }
    }

    // MARK: Codable

    required convenience public init(from decoder: Decoder) throws {
        let json = try JSONValue(from: decoder)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = ModelDateFormatting.encodingStrategy

        // metadata decoding
        if let payload = try? AppSyncListPayload.init(from: decoder) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = ModelDateFormatting.decodingStrategy
            let elements = try payload.getItems().map { (jsonElement) -> ModelType in
                let serializedJSON = try encoder.encode(jsonElement)
                return try decoder.decode(ModelType.self, from: serializedJSON)
            }

            self.init(elements,
                      nextToken: payload.getNextToken(),
                      document: payload.document,
                      variables: payload.variables)
            return
        }

        // base decoding
        guard case let .object(jsonObject) = json,
              case let .array(jsonArray) = jsonObject["items"] else {
            self.init([ModelType]())
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ModelDateFormatting.decodingStrategy
        let elements = try jsonArray.map { (jsonElement) -> ModelType in
            let serializedJSON = try encoder.encode(jsonElement)
            return try decoder.decode(ModelType.self, from: serializedJSON)
        }

        self.init(elements)
    }
}
