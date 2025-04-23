//
//  OpenAIConfiguration+Extensions.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/18/25.
//

import Foundation
import AppKit
import SwiftData

// MARK: Context and Instructions
extension OpenAINetworkManager {
    static var executorInstructionContents: String {
        guard let file = Bundle.main.path(forResource: "ExecutorInstructions", ofType: "md"),
              let contents = try? String(contentsOfFile: file, encoding: .utf8) else { return "" }
        return contents
    }
    
    static var strategistInstructionContents: String {
        guard let file = Bundle.main.path(forResource: "StrategistInstructions", ofType: "md"),
              let contents = try? String(contentsOfFile: file, encoding: .utf8) else { return "" }
        return contents
    }
    
    static var singleExecutorInstructionContents: String {
        guard let file = Bundle.main.path(forResource: "SingleExecutorInstructions", ofType: "md"),
              let contents = try? String(contentsOfFile: file, encoding: .utf8) else { return "" }
        return contents
    }
    
    static var defaultTools: [OpenAITool] {
        return OpenAIFunction.defaultFunctions.map({ return OpenAITool($0) })
    }
    
}


extension OpenAIFunction {
    static let defaultFunctions: [OpenAIFunction] = [
        .init(name: "current-date",
              description: "When the user asks for date-specific information, you are granted access to this information using this function, which returns an ISO-8601 string. Note, you do not have to use the entire data for any given response. If the user asks for the time, give it to them in their local time zone.",
              parameters: .init(
                type: "object",
                properties: [:],
                required: [],
                additionalProperties: false),
              strict: false,
              executorFunction: { _ in
                  let formatter = ISO8601DateFormatter()
                  formatter.timeZone = Calendar.current.timeZone
                  return formatter.string(from: Date.now)
              }),
        .init(name: "open-url-in-browser",
              description: "When the user asks to be taken to a specific webpage (or if it would help with your response, like a tutorial or something), you can call this function which will open this page in the default browser.",
              parameters: .init(
                type: "object",
                properties: ["url": .init(
                    type: "string",
                    enumerable: nil,
                    description: "The https url that should be opened by the browser.")],
                required: ["url"],
                additionalProperties: false),
              strict: true,
              executorFunction: { props in
                  guard let urlStr = props["url"],
                        let url = URL(string: urlStr),
                        url.scheme == "https" else {
                      return "Invalid input"
                  }
                  
                  guard let (_,response) = try? await URLSession.shared.data(from: url),
                            let http = response as? HTTPURLResponse else {
                      return "Unable to connect to target website"
                  }
                  
                  
                  NSWorkspace.shared.open(url)
                  return "Successfully opened: \(url.absoluteString)"
              }),
        .init(name: "take-screenshot",
              description: "When the user asks for help or information on their screen, you can use this function to get a capture of their running application. Can fail if screenshot permission is not allowed",
              parameters: .init(type: "object", properties: [:], required: [], additionalProperties: false),
              strict: true,
              executorFunction: { _ in
                  return "SYSTEM MESSAGE: Taking screenshot. Will send in future call."
              },
              callbackInput: { _ in
                  if let img = await AIScreenshotManager.takeScreenshot() {
                      return OpenAIImageContentInput(image: img, message: "Here is the image. Proceed with the original request.")
                  } else {
                      return OpenAIContentInput(content: "Failed to take a screenshot. Try to proceed without it.", role: "developer")
                  }
              }),
        .init(name: "ask-strategist",
              description: "You should ask the strategist for a new plan if something isn't where the strategist thought it would be, an unexpected outcome occurs, or something that might change the plan.",
              parameters: .init(type: "object",
                                properties: [
                                    "message": .init(
                                        type: "string",
                                        enumerable: nil,
                                        description: "The message that you're sending the strategist. Talk about what the original plan was, what you tried, why you think it's not going to work, and what the new plan should be. Ask if there are some more APIs that you could call that might solve the problem."),
                                    "originalRequest": .init(
                                        type: "string",
                                        enumerable: nil,
                                        description: "An exact copy of the user's original request.")],
                                required: ["message", "originalRequest"],
                                additionalProperties: false),
              strict: true,
              executorFunction: { params in
                  guard let msg = params["message"], let req = params["originalRequest"] else { return "You didn't give the strategist a message or the original request."}
                  let messageCombined =
                              """
                                <CALLBACK FROM EXECUTOR>
                                \(msg)
                                </CALLBACK FROM EXECUTOR>
                              
                                <ORIGINAL REQUEST>
                                \(req)
                                </ORIGINAL REQUEST>
                              """
                  let strategistRequest = OpenAIAPIRequest(model: "gpt-4.1", input: messageCombined, instructions: OpenAINetworkManager.strategistInstructionContents)
                  guard let strategistResponse = try? await OpenAINetworkManager.executeOpenAIRequest(strategistRequest),
                        let newStrategy = strategistResponse.textMessage else {
                      return "SYSTEM MESSAGE: The strategist did not respond. Try with the original request as best you can."
                  }
                  
                  return newStrategy
              }),
        .init(name: "get-request-public",
              description: "A general, unauthenticated GET-request for an API. The details you give will be execute exactly as given with no authentication injected into the request. You will be returned the exact data returned by the request, encoded as UTF-8. Importantly, so that you don't lose context, if you have the ability to filter results or only include necessary fields, you should do so.",
              parameters: .init(type: "object",
                                properties: [
                                    "url": .init(
                                        type: "string",
                                        enumerable: nil,
                                        description: "The complete URL that will be placed in the get request. Should include all necessary query parameters in-line")],
                                required: ["url"],
                                additionalProperties: false),
              strict: true,
              executorFunction: { params in
                  guard let urlStr = params["url"] else { return "You didn't provide a URL."}
                  guard let url = URL(string: urlStr) else {return "The URL you provided was invalid."}
                  
                  guard let (data, response) = try? await URLSession.shared.data(from: url),
                        let http = response as? HTTPURLResponse else { return "Unable to execute GET request." }
                  
                  guard let dataStr = String(data: data, encoding: .utf8) else { return "Unable to parse data"}
                  guard http.statusCode == 200 else { return "Server returned error code \(http.statusCode)\n\n\(dataStr)"}
                  return dataStr
              }),
        .init(name: "get-request-authenticated",
              description: "A general, authenticated GET-request for an API. The details you give will be executed exactly as given, and the credential you specify will be injected into the request out of your purview.. You will be returned the exact data returned by the request, encoded as UTF-8. Importantly, so that you don't lose context, if you have the ability to filter results or only include necessary fields, you should do so.",
              parameters: .init(type: "object",
                                properties: [
                                    "url": .init(
                                        type: "string",
                                        enumerable: nil,
                                        description: "The complete URL that will be placed in the get request. Should include all necessary query parameters in-line"),
                                    "service": .init(
                                        type: "string",
                                        enumerable: ApplicationViewModel.shared.accessTokens.map({ $0.0.canonicalName }),
                                        description: "The service whose credential will be put in the valid request headers.")
                                ],
                                required: ["url", "service"],
                                additionalProperties: false),
              strict: true,
              executorFunction: { params in
                  guard let urlStr = params["url"] else { return "You didn't provide a URL."}
                  guard let url = URL(string: urlStr) else {return "The URL you provided was invalid."}
                  guard let service = params["service"] else { return "You didn't provide a service."}
                  guard let enumService = AuthManager.UserAPIServices.allCases.first(where: { $0.canonicalName == service }) else {
                      return "This service doesn't exist."
                  }
                  
                  guard let request = try? await URLRequest(url: url, service: enumService) else { return "Failed to authenticate with \(service). Try another way."}
                  
                  guard let (data, response) = try? await URLSession.shared.data(for: request),
                        let http = response as? HTTPURLResponse else { return "Unable to execute GET request." }
                  
                  guard let dataStr = String(data: data, encoding: .utf8) else { return "Unable to parse data"}
                  guard http.statusCode == 200 else { return "Server returned error code \(http.statusCode)\n\n\(dataStr)"}
                  return dataStr
              }),
        .init(name: "post-request-authenticated",
              description: "A general, authenticated POST-request for an API. You should be VERY careful with this, for this can lead to unwanted consequences. Consider asking the user to confirm before doing this. The details you give will be executed exactly as given, and the credential you specify will be injected into the request out of your purview.. You will be returned the exact data returned by the request, encoded as UTF-8. Importantly, so that you don't lose context, if you have the ability to filter results or only include necessary fields, you should do so.",
              parameters: .init(type: "object",
                                properties: [
                                    "url": .init(
                                        type: "string",
                                        enumerable: nil,
                                        description: "The complete URL that will be placed in the post request."),
                                    "body": .init(
                                        type: "string",
                                        enumerable: nil,
                                        description: "The HTTP body that will be passed in the request. This is a JSON object that does not include any escape characters, such as \\ infront of quotes. HTTP Bodies with escape characters are not encoded correctly and will always result in a bad request, so don't include them in this string."),
                                    "service": .init(
                                        type: "string",
                                        enumerable: ApplicationViewModel.shared.accessTokens.map({ $0.0.canonicalName }),
                                        description: "The service whose credential will be put in the valid request headers.")
                                ],
                                required: ["url", "body", "service"],
                                additionalProperties: false),
              strict: true,
              executorFunction: { params in
                  guard let urlStr = params["url"] else { return "You didn't provide a URL."}
                  guard let url = URL(string: urlStr) else {return "The URL you provided was invalid."}
                  guard let service = params["service"] else { return "You didn't provide a service."}
                  guard let bodyStr = params["body"] else { return "You didn't provide an HTTP Body."}
                  guard let enumService = AuthManager.UserAPIServices.allCases.first(where: { $0.canonicalName == service }) else {
                      return "This service doesn't exist."
                  }
                  
                  guard let bodyData = bodyStr.data(using: .utf8) else { return "Failed to encode HTTP body" }
                  guard var request = try? await URLRequest(url: url, service: enumService) else { return "Failed to authenticate with \(service). Try another way."}
                  request.httpMethod = "POST"
                  request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                  request.httpBody = bodyData
                  guard let (data, response) = try? await URLSession.shared.data(for: request),
                        let http = response as? HTTPURLResponse else { return "Unable to execute POST request." }
                  
                  
                  guard let dataStr = String(data: data, encoding: .utf8) else { return "Unable to parse data"}
                  guard http.statusCode == 200 else { return "Server returned error code \(http.statusCode)\n\n\(dataStr)"}
                  return dataStr
              }),
        .init(
            name: "get-authenticated-services",
            description: "Returns the list of services that you have access to authenticated endpoints. You can call these with get and post requests.",
            parameters: .init(type: "object", properties: [:], required: [], additionalProperties: false),
            strict: true,
            executorFunction: { _ in
                return ApplicationViewModel.shared.accessTokens.map({ $0.0.canonicalName }).joined(separator: ", ")
            }),
        .init(
            name: "get-container-storage-keys",
            description: "You can fetch a set of keys that point to storage containers. Given a key returned by this function, you can call the get-container function to retrieve that data. These containers either store a single JSON object or they store an array. Use this dat to inform future queries. One of these containers is the preferences, so you should call this to get the key to local preferences, in order to access that container in a future call.",
            parameters: .init(type: "object", properties: [:], required: [], additionalProperties: false),
            strict: true,
            executorFunction: { _ in
                do {
                    let containers = try ContainersManager.getAllContainers()
                    let keysAndContainers = containers.keysAndContainers
                    let data = try JSONEncoder().encode(keysAndContainers)
                    return String(data: data, encoding: .utf8) ?? "No storage containers found."
                } catch {
                    if let err = error as? ContainersError {
                        return err.localizedDescription
                    } else {
                        return "Unable to fetch local storage containers."
                    }
                }
            }),
        .init(
            name: "get-container",
            description: "Returns the JSON-encoded data for a container in local storage. You can access the keys using the get-container-storage-keys function. You pass in the key for the container, as well as the expected type, and it will return the data.",
            parameters: .init(
                type: "object",
                properties: [
                    "key": .init(
                        type: "string",
                        enumerable: nil,
                        description: "The key for the container returned by the get-container-storage-keys function"),
                    "type": .init(
                        type: "string",
                        enumerable: ["single", "multiple/array"],
                        description: "The type of the storage container. Some containers hold singleton JSON objects, whereas others contain an array of JSON objects indexed by an ID property.")
                    ],
                required: ["key", "type"],
                additionalProperties: false),
            strict: true,
            executorFunction: { args in
                guard let key = args["key"], let type = args["type"] else {
                    return "Missing argument."
                }
                
                print("Trying to fetch \(type) container: \(key).")
                
                do {
                    let anyContainer = try ContainersManager.getContainerByKey(key, type: type)
                    let data: Data
                    let encoder = JSONEncoder()
                    if let container = anyContainer as? DynamAIcSingleStorageContainer, type == "single" {
                        data = try JSONEncoder().encode(container)
                    } else if let container = anyContainer as? DynamAIcMultipleStorageContainer, type == "multiple/array" {
                        data = try JSONEncoder().encode(container)
                    } else {
                        throw ContainersError.containerTypeMismatch
                    }
                    
                    return String(data: data, encoding: .utf8) ?? "Unable to parse container."
                } catch {
                    if let err = error as? ContainersError {
                        return err.localizedDescription
                    } else {
                        return "Failed to fetch container."
                    }
                }
            })
    ]
}
