//
//  OpenAIConfiguration+Extensions.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/18/25.
//

import Foundation
import AppKit

// MARK: Context and Instructions
extension OpenAINetworkManager {
    static var markdownInstructionContents: String {
        guard let file = Bundle.main.path(forResource: "Instructions", ofType: "md"),
              let contents = try? String(contentsOfFile: file, encoding: .utf8) else { return "" }
        return contents
    }
    
    static var strategistInstructionContents: String {
        guard let file = Bundle.main.path(forResource: "StrategistInstructions", ofType: "md"),
              let contents = try? String(contentsOfFile: file, encoding: .utf8) else { return "" }
        return contents
    }
    
    static var defaultTools: [OpenAITool] {
        return OpenAIFunction.defaultFunctions.map({ return OpenAITool($0) })
    }
    
}


extension OpenAIFunction {
    static let defaultFunctions: [OpenAIFunction] = [
        .init(name: "fetch-local-storage",
              description: "When the user asks for something relating to memory/persistent data, this function returns the entire stored data in a key-value dictionary",
              parameters: .init(
                type: "object",
                properties: [:],
                required: [],
                additionalProperties: false),
              strict: false,
              executorFunction: { _ in return "{go to the gym, zoom personal PMI: 3641119944}"}),
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
                  guard http.statusCode == 200 else {
                      return "Website does not return OK status code, instead returned \(http.statusCode)"
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
                  
                  guard http.statusCode == 200 else { return "Server returned error code \(http.statusCode)"}
                  guard let dataStr = String(data: data, encoding: .utf8) else { return "Unable to parse data"}
                  return dataStr
              })
    ]
}
