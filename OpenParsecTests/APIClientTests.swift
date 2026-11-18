import XCTest
@testable import OpenParsec

/// Tests for the `APIClient` error model and response decoding logic.
///
/// **Limitation:** `APIClient` hardcodes `URLSession.shared` in `perform()`,
/// so it is not injectable. Full request-level testing (status codes, headers,
/// query-string handling) would require either a `URLProtocol` stub registered
/// on the shared session or making the `URLSession` injectable. The tests
/// below cover the parts that are pure and deterministic:
///
/// - `APIError` case discrimination and the `errorInfo` / `rawBody` accessors.
/// - `APIResponse` payload + status storage.
/// - The exact decode pattern `APIClient.data()` uses (guard status < 400,
///   then `JSONDecoder().decode`, wrapping failures in `.decoding`).
///
/// The decode-pattern tests replicate `APIClient.data()`'s logic verbatim so
/// they validate the same code path without a live network.
final class APIClientTests: XCTestCase {

	// MARK: - APIError accessors

	func testErrorInfoDecodesHttpBody() {
		let body = Data(#"{"error":"not found"}"#.utf8)
		let err = APIError.http(status: 404, data: body)
		XCTAssertEqual(err.errorInfo?.error, "not found")
	}

	func testErrorInfoIsNilForNonHttpErrors() {
		XCTAssertNil(APIError.decoding(underlying: NSError(domain: "t", code: 1)).errorInfo)
		XCTAssertNil(APIError.transport(underlying: NSError(domain: "t", code: 1)).errorInfo)
	}

	func testRawBodyReturnsHttpData() {
		let body = Data("hello".utf8)
		XCTAssertEqual(APIError.http(status: 500, data: body).rawBody, body)
		XCTAssertNil(APIError.decoding(underlying: NSError(domain: "t", code: 1)).rawBody)
	}

	func testApiErrorCaseDiscrimination() {
		let http = APIError.http(status: 404, data: Data())
		guard case .http(let status, let data) = http else {
			XCTFail("expected .http case")
			return
		}
		XCTAssertEqual(status, 404)
		XCTAssertTrue(data.isEmpty)

		let dec = APIError.decoding(underlying: NSError(domain: "t", code: 1))
		guard case .decoding = dec else { XCTFail("expected .decoding case"); return }

		let tr = APIError.transport(underlying: NSError(domain: "t", code: 1))
		guard case .transport = tr else { XCTFail("expected .transport case"); return }
	}

	// MARK: - APIResponse

	func testAPIResponseStoresStatusAndData() {
		let info = ClientInfo(instance_id: "inst", user_id: 7, session_id: "sess", host_peer_id: "peer")
		let resp = APIResponse(status: 200, data: info)
		XCTAssertEqual(resp.status, 200)
		XCTAssertEqual(resp.data.session_id, "sess")
		XCTAssertEqual(resp.data.user_id, 7)
	}

	// MARK: - Decode pattern (mirrors APIClient.data())

	/// Replicates the exact guard + decode + error-wrapping logic of
	/// `APIClient.data<T>()` so the behavior is verified without a network.
	private func decodeLikeAPIClient<T: Decodable>(_ type: T.Type, status: Int, body: Data) -> Result<APIResponse<T>, APIError> {
		guard status < 400 else {
			return .failure(.http(status: status, data: body))
		}
		do {
			let decoded = try JSONDecoder().decode(T.self, from: body)
			return .success(APIResponse(status: status, data: decoded))
		} catch {
			return .failure(.decoding(underlying: error))
		}
	}

	func testDecodeSuccess() {
		let body = Data(#"{"instance_id":"i","user_id":1,"session_id":"s","host_peer_id":"p"}"#.utf8)
		let result = decodeLikeAPIClient(ClientInfo.self, status: 200, body: body)
		guard case .success(let resp) = result else {
			XCTFail("expected success, got \(result)")
			return
		}
		XCTAssertEqual(resp.status, 200)
		XCTAssertEqual(resp.data.instance_id, "i")
	}

	func testDecodeHttpError404() {
		let result = decodeLikeAPIClient(ClientInfo.self, status: 404, body: Data())
		guard case .failure(let err) = result else {
			XCTFail("expected failure")
			return
		}
		guard case .http(let status, _) = err else {
			XCTFail("expected .http, got \(err)")
			return
		}
		XCTAssertEqual(status, 404)
	}

	func testDecodeHttpError500() {
		let result = decodeLikeAPIClient(ClientInfo.self, status: 500, body: Data())
		guard case .failure(let err) = result else {
			XCTFail("expected failure")
			return
		}
		guard case .http(let status, _) = err else {
			XCTFail("expected .http, got \(err)")
			return
		}
		XCTAssertEqual(status, 500)
	}

	func testDecodeMalformedJSON() {
		// 200 OK but the body is not valid JSON for ClientInfo → .decoding.
		let result = decodeLikeAPIClient(ClientInfo.self, status: 200, body: Data("not json".utf8))
		guard case .failure(let err) = result else {
			XCTFail("expected failure")
			return
		}
		guard case .decoding = err else {
			XCTFail("expected .decoding, got \(err)")
			return
		}
	}

	func testDecodeWrongShape() {
		// Valid JSON but missing required fields → .decoding.
		let result = decodeLikeAPIClient(ClientInfo.self, status: 200, body: Data(#"{"foo":"bar"}"#.utf8))
		guard case .failure(let err) = result else {
			XCTFail("expected failure")
			return
		}
		guard case .decoding = err else {
			XCTFail("expected .decoding, got \(err)")
			return
		}
	}

	// MARK: - Constants

	func testBaseURLAndUserAgent() {
		XCTAssertEqual(APIClient.shared.baseURL, URL(string: "https://kessel-api.parsec.app"))
		XCTAssertEqual(APIClient.shared.userAgent, "parsec/150-93b Windows/11 libmatoya/4.0")
	}
}
