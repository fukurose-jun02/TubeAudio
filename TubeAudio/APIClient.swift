import Foundation
import Observation

struct VideoInfo: Decodable {
    let title: String
    let thumbnail: String
    let channel: String
    let duration_str: String
}

struct JobStatus: Decodable {
    let status: String
    let progress: Int?
    let title: String?
    let filename: String?
    let filesize: String?
    let error: String?
}

@Observable
class APIClient {
    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }

    init() {
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://192.168.1.6:5001"
    }

    func fetchInfo(url: String) async throws -> VideoInfo {
        var req = URLRequest(url: URL(string: "\(serverURL)/api/info")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["url": url])
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(VideoInfo.self, from: data)
    }

    func startConvert(url: String, format: String, quality: String) async throws -> String {
        var req = URLRequest(url: URL(string: "\(serverURL)/api/convert")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["url": url, "format": format, "quality": quality])
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONDecoder().decode([String: String].self, from: data)
        guard let jobId = json["job_id"] else { throw URLError(.badServerResponse) }
        return jobId
    }

    func pollStatus(jobId: String) async throws -> JobStatus {
        let url = URL(string: "\(serverURL)/api/status/\(jobId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(JobStatus.self, from: data)
    }

    func downloadFile(jobId: String, filename: String) async throws -> URL {
        let url = URL(string: "\(serverURL)/api/download/\(jobId)")!
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }
}
