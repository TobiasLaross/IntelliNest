@testable import IntelliNest
import Foundation

func makeEntityJSON(entityId: String, state: String) -> Data {
    Data("""
    {
        "entity_id": "\(entityId)",
        "state": "\(state)",
        "last_changed": "2023-06-17T13:30:00.215607+00:00",
        "last_updated": "2023-06-17T13:30:00.215607+00:00"
    }
    """.utf8)
}

func stubEntityURL(entityID: EntityId, state: String) {
    let url = entityStateURL(for: entityID)
    let data = makeEntityJSON(entityId: entityID.rawValue, state: state)
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    URLProtocolStub.setStub(for: url, data: data, response: response, error: nil)
}

func stubEntityURL(entityID: EntityId, data: Data) {
    let url = entityStateURL(for: entityID)
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    URLProtocolStub.setStub(for: url, data: data, response: response, error: nil)
}

private func entityStateURL(for entityID: EntityId) -> URL {
    var components = URLComponents(string: GlobalConstants.baseInternalUrlString)!
    components.path = "/api/states/\(entityID.rawValue)"
    return components.url!
}
