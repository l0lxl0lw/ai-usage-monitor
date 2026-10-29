import Foundation

public enum Route: Hashable { case usage, agents, account(UUID), agent(AgentID), settings }
public struct NavigationState {
    public var route: Route = .usage
    public private(set) var stack: [Route] = []
    public var scroll: [Route: String] = [:]
    public var offsets: [Route: Double] = [:]
    public var query = ""
    public var project: String?
    public var state: Activity?
    public var collapsed: Set<AgentID> = []
    public init() {}
    public mutating func push(_ next: Route) { stack.append(route); route = next }
    @discardableResult public mutating func back() -> Bool {
        guard let previous = stack.popLast() else { return false }; route = previous; return true
    }
    public mutating func tab(_ next: Route) { route = next; stack = [] }
    public mutating func toggle(_ id: AgentID) { if !collapsed.insert(id).inserted { collapsed.remove(id) } }
}
