#!/usr/bin/env xcrun swift -F Framework

import CLIKit
import PrettyColors

typealias JSONDictionary = [String: AnyObject]

enum ParsingError: ErrorType
{
    case NoErrorMessageFromServer
    case NoErrorMessageDetail
    case InvalidResponse
}

var manager: CLIKit.Manager = Manager()

enum Type: String
{
    case Channel = "channel"
    case Group = "group"
    
    func apiKey() -> String
    {
        return "\(self.rawValue)s"
    }
}

protocol Community
{
    var id: String { get }
    var name: String { get }
    var type: Type { get }
    
    func label() -> String
}

struct Channel: Community
{
    let id: String
    let name: String
    var type = Type.Channel
    
    init(dictionary: JSONDictionary)
    {
        id = dictionary["id"] as? String ?? ""
        name = dictionary["name"] as? String ?? ""
    }
    
    func label() -> String
    {
        return "#\(name)"
    }
}

struct Group: Community
{
    let id: String
    let name: String
    var type = Type.Group
    
    init(dictionary: JSONDictionary)
    {
        id = dictionary["id"] as? String ?? ""
        name = dictionary["name"] as? String ?? ""
    }
    
    func label() -> String
    {
        return "\(name) \(type.rawValue)"
    }
}

func api(method: String, token: String) -> String
{
    return "https://slack.com/api/\(method)?token=\(token)"
}

func list(type: Type, token: String) -> [JSONDictionary]?
{
    let urlString = api("\(type.apiKey()).list", token: token)
    let url = NSURL(string: urlString)
    let request = NSURLRequest(URL: url!)
    var response: NSURLResponse?
    do
    {
        let urlData = try NSURLConnection.sendSynchronousRequest(request, returningResponse: &response)
        let jsonResult = try NSJSONSerialization.JSONObjectWithData(urlData, options: NSJSONReadingOptions.MutableContainers) as? JSONDictionary

		if let jsonResult = jsonResult, ok = jsonResult["ok"] as? Bool
        {
            if (ok)
            {
                if let results = jsonResult[type.apiKey()] as? [JSONDictionary]
                {
                    return results
                }
                else
                {
                    return nil
                }
            }
            else
            {
                let reason = jsonResult["error"] as? String ?? "Unknown error"
                let errorMessage: String = Color.Wrap(foreground: .Red).wrap("Failed from \"list\" with error message: \(reason)")
                print(errorMessage)
                return nil
            }
		}
		else
        {
            let errorMessage: String = Color.Wrap(foreground: .Red).wrap("Failed from \"list\" with error message: Unknown error")
            print(errorMessage)
			return nil
		}
    }
    catch let error as NSError
    {
        let errorMessage: String = Color.Wrap(foreground: .Red).wrap("Failed from \"list\" with request error: \(error)")
        print(errorMessage)
		return nil
    }
}

func postMessage(id: String, text: String, token: String)
{
    let urlString = api("chat.postMessage", token: token)
    let url = NSURL(string: "\(urlString)&channel=\(id)&text=\(encodeString(text))")
    let request = NSURLRequest(URL: url!)
    var response: NSURLResponse?
    do
    {
        let urlData = try NSURLConnection.sendSynchronousRequest(request, returningResponse: &response)
        let jsonResult = try NSJSONSerialization.JSONObjectWithData(urlData, options: NSJSONReadingOptions.MutableContainers) as? JSONDictionary
        
        if let jsonResult = jsonResult, ok = jsonResult["ok"] as? Bool
        {
            if (ok)
            {
                let message: String = Color.Wrap(foreground: .Green).wrap("Success")
                print(message)
            }
            else
            {
                let reason = jsonResult["error"] as? String ?? "Unknown error"
                let errorMessage: String = Color.Wrap(foreground: .Red).wrap("Failed from \"postMessage\" with error message: \(reason)")
                print(errorMessage)
            }
        }
        else
        {
            let errorMessage: String = Color.Wrap(foreground: .Red).wrap("Failed from \"postMessage\" with error message: Unknown error")
            print(errorMessage)
        }
    }
    catch let error as NSError
    {
        let errorMessage: String = Color.Wrap(foreground: .Red).wrap("Failed from \"postMessage\" with request error: \(error)")
        print(errorMessage)
    }
}

func encodeString(string: String) -> String
{
    return string.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding) ?? ""
}


manager.register("post", "Post to a channel or group") { argv in

    if let type = argv.option("type"), name = argv.option("name"), token = argv.option("token")
    {
        if let message = argv.option("message")
        {
            let parsedResult: [Community]?
            if (Type.Channel.apiKey().hasPrefix(type))
            {
                parsedResult = list(.Channel, token: token)?.map() { Channel(dictionary: $0 ?? [:]) } ?? []
            }
            else if (Type.Group.apiKey().hasPrefix(type))
            {
                parsedResult = list(.Group, token: token)?.map() { Group(dictionary: $0 ?? [:]) } ?? []
            }
            else
            {
                parsedResult = nil
            }
            
            if let parsedResult = parsedResult
            {
                var targetCommunity: Community? = nil
                for community in parsedResult
                {
                    if (community.name == name)
                    {
                        targetCommunity = community
                        break
                    }
                }
                
                if let targetCommunity = targetCommunity
                {
                    let message: String = Color.Wrap(foreground: .Green).wrap("Posting \"\(message)\" to \(targetCommunity.label()) ...")
                    print(message)
                    postMessage(targetCommunity.id, text: message, token: token)
                }
                else
                {
                    if (Type.Channel.apiKey().hasPrefix(type))
                    {
                        let errorMessage: String = Color.Wrap(foreground: .Red).wrap("Error: Unknown \(Type.Channel.rawValue).")
                        print(errorMessage)
                    }
                    else if (Type.Group.apiKey().hasPrefix(type))
                    {
                        let errorMessage: String = Color.Wrap(foreground: .Red).wrap("Error: Unknown \(Type.Channel.rawValue).")
                        print(errorMessage)
                    }
                    else
                    {
                        let errorMessage: String = Color.Wrap(foreground: .Red).wrap("Error: Unknown type.")
                        print(errorMessage)
                    }
                }
            }
            else
            {
                let errorMessage: String = Color.Wrap(foreground: .Red).wrap("Error: Unsupported type.")
                print(errorMessage)
            }
        }
        else
        {
            let errorMessage: String = Color.Wrap(foreground: .Red).wrap("Error: Empty message.")
            print(errorMessage)
        }
    }
    else
    {
        let errorMessage: String = Color.Wrap(foreground: .Red).wrap("Error: Type not specified.")
        print(errorMessage)
    }
}

manager.run()
