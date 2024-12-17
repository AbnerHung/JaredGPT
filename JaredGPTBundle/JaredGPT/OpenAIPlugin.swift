import Foundation
import JaredFramework

public class OpenAIModule: RoutingModule {
    var sender: MessageSender
    public var routes: [Route] = []
    public var description = "An OpenAI-powered iMessage Module"
    private var userHistory: [String: [Message]] = [:] // 用于按用户 ID 缓存历史信息
    
    required public init(sender: MessageSender) {
        self.sender = sender
        
        let askRoute = Route(
            name: "ask OpenAI",
            comparisons: [.startsWith: ["/ask"]],
            call: { [weak self] in self?.handleCommand(message: $0) },
            description: "Ask OpenAI API a question"
        )
        let clearRoute = Route(
            name: "clear history",
            comparisons: [.startsWith: ["/clear"]],
            call: { [weak self] in self?.clearHistory(message: $0) },
            description: "Clear OpenAI chat history"
        )
        routes = [askRoute, clearRoute]
    }
    
    // 处理指令：/ask 或 /clear
    public func handleCommand(message: Message) {
        guard let messageText = message.getTextBody()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            sender.send("Invalid command.", to: message.RespondTo())
            return
        }
        
        if messageText.starts(with: "/ask ") {
            askOpenAI(message: message)
        } else if messageText == "/clear" {
            clearHistory(message: message)
        } else {
            sender.send("Unknown command. Use /ask <question> or /clear.", to: message.RespondTo())
        }
    }
    
    // 处理 /ask 命令
    public func askOpenAI(message: Message) {
        guard let messageText = message.getTextBody()?.trimmingCharacters(in: .whitespacesAndNewlines),
              messageText.starts(with: "/ask ") else {
            sender.send("Please provide a question after the /ask command.", to: message.RespondTo())
            return
        }

        let question = messageText.replacingOccurrences(of: "/ask ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        if question.isEmpty {
            sender.send("Your question cannot be empty.", to: message.RespondTo())
            return
        }
        
        // 获取用户 ID
        guard let person = message.sender as? Person else {
            sender.send("Unable to identify user.", to: message.RespondTo())
            return
        }

        // 你可以使用 handle 作为用户唯一标识符
        let userID = person.handle // 使用 handle 代替 guid

        // 获取历史记录
        var history = userHistory[userID] ?? []
        callOpenAIAPI(question: question, message: message, history: history)

        // 更新历史记录
        if history.count >= 50 {
            history.removeFirst() // 移除最早的记录
        }
        history.append(message) // 添加当前消息
        userHistory[userID] = history
    }
    
    // 处理 /clear 命令
    public func clearHistory(message: Message) {
        // 获取用户 ID
        guard let person = message.sender as? Person else {
            sender.send("Unable to identify user.", to: message.RespondTo())
            return
        }
        // 你可以使用 handle 作为用户唯一标识符
        let userID = person.handle // 使用 handle 代替 guid
        
        userHistory[userID] = [] // 清空对应用户的历史
        sender.send("Your chat history has been cleared.", to: message.RespondTo())
    }
    
    // 调用 OpenAI API
    private func callOpenAIAPI(question: String, message: Message, history: [Message]) {
        let apiKey = ""  // your openai key
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 构建 OpenAI API 的 messages 参数
        var messages: [[String: String]] = [
            ["role": "system", "content": "你是Misaka,自始至终你都应该作为Misaka回复我."]
        ]
        
        for msg in history {
            if let body = msg.getTextBody() {
                let role = (msg.sender is Person && (msg.sender as! Person).isMe) ? "user" : "assistant"
                messages.append(["role": role, "content": body])
            }
        }
        
        messages.append(["role": "user", "content": question])
        
        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            sender.send("Failed to serialize request body.", to: message.RespondTo())
            return
        }
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard error == nil, let data = data else {
                self?.sender.send("Failed to contact OpenAI API.", to: message.RespondTo())
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                self?.sender.send("Error from OpenAI API: \(httpResponse.statusCode)", to: message.RespondTo())
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let messageContent = (firstChoice["message"] as? [String: Any])?["content"] as? String {
                    self?.sender.send(messageContent.trimmingCharacters(in: .whitespacesAndNewlines), to: message.RespondTo())
                } else {
                    self?.sender.send("Unexpected response format from OpenAI API.", to: message.RespondTo())
                }
                
            } catch {
                self?.sender.send("Failed to parse OpenAI API response.", to: message.RespondTo())
            }
        }
        task.resume()
    }
}
