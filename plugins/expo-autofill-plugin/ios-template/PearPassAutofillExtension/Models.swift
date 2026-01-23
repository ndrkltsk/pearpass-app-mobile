import Foundation
import SwiftUI
import AuthenticationServices

struct Vault: Equatable {
    let id: String
    let name: String
    let version: Int
    let records: [[String: Any]]
    let devices: [[String: Any]]
    let createdAt: Date
    let updatedAt: Date
    let encryption: VaultEncryption?
    
    struct VaultEncryption: Equatable {
        let ciphertext: String
        let nonce: String
        let hashedPassword: String?
        let salt: String?
        
        static func == (lhs: VaultEncryption, rhs: VaultEncryption) -> Bool {
            return lhs.ciphertext == rhs.ciphertext && 
                   lhs.nonce == rhs.nonce &&
                   lhs.hashedPassword == rhs.hashedPassword &&
                   lhs.salt == rhs.salt
        }
    }
    
    static func == (lhs: Vault, rhs: Vault) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.version == rhs.version &&
               lhs.createdAt == rhs.createdAt &&
               lhs.updatedAt == rhs.updatedAt &&
               lhs.encryption == rhs.encryption
    }
}

struct Credential {
    let id: String
    let name: String
    let username: String
    let password: String
    let websites: [String]
}

enum AuthFlow: Equatable {
    case missingConfiguration
    case masterPassword
    case vaultSelection
    case vaultPassword(vault: Vault)
    case credentialsList(vault: Vault)
    
    static func == (lhs: AuthFlow, rhs: AuthFlow) -> Bool {
        switch (lhs, rhs) {
        case (.missingConfiguration, .missingConfiguration),
             (.masterPassword, .masterPassword),
             (.vaultSelection, .vaultSelection):
            return true
        case (.vaultPassword(let lhsVault), .vaultPassword(let rhsVault)),
             (.credentialsList(let lhsVault), .credentialsList(let rhsVault)):
            return lhsVault.id == rhsVault.id
        default:
            return false
        }
    }
}

class ExtensionViewModel: ObservableObject {
    @Published var currentFlow: AuthFlow = .masterPassword
    @Published var masterPassword: String = ""
    @Published var vaultPassword: String = ""
    @Published var selectedVault: Vault?
    @Published var searchText: String = ""
    @Published var vaults: [Vault] = []  // Store actual vaults from the API
    
    func authenticateWithMasterPassword() {
        currentFlow = .vaultSelection
        masterPassword = ""
    }
    
    func selectVault(_ vault: Vault) {
        selectedVault = vault
        currentFlow = .vaultPassword(vault: vault)
    }
    
    func authenticateWithVaultPassword() {
        guard let vault = selectedVault else { return }
        currentFlow = .credentialsList(vault: vault)
        vaultPassword = ""
    }
    
    func goBackToVaultSelection() {
        currentFlow = .vaultSelection
        selectedVault = nil
    }
}

// MARK: - Passkey Models

/// Response data for passkey registration (matches browser extension structure exactly)
struct PasskeyResponse: Codable, Equatable {
    let clientDataJSON: String       // Base64URL
    let attestationObject: String    // Base64URL
    let authenticatorData: String    // Base64URL
    let publicKey: String            // Base64URL SPKI
    let publicKeyAlgorithm: Int      // -7 for ES256
    let transports: [String]         // ["internal"]
}

/// Client extension results
struct PasskeyClientExtensionResults: Codable, Equatable {
    let credProps: PasskeyCredProps?
}

struct PasskeyCredProps: Codable, Equatable {
    let rk: Bool  // Resident key / discoverable credential
}

/// Complete passkey credential (matches browser extension structure exactly)
struct PasskeyCredential: Equatable {
    let id: String                   // Base64URL credential ID
    let rawId: String                // Base64URL (same as id)
    let type: String                 // "public-key"
    let response: PasskeyResponse
    let authenticatorAttachment: String  // "platform"
    let clientExtensionResults: PasskeyClientExtensionResults
    let _privateKeyBuffer: Data      // PKCS#8 private key (binary buffer)
    let _userId: String              // Base64URL user ID

    /// Create a new passkey credential
    static func create(
        credentialId: String,
        response: PasskeyResponse,
        privateKeyBuffer: Data,
        userId: String
    ) -> PasskeyCredential {
        PasskeyCredential(
            id: credentialId,
            rawId: credentialId,
            type: "public-key",
            response: response,
            authenticatorAttachment: "platform",
            clientExtensionResults: PasskeyClientExtensionResults(
                credProps: PasskeyCredProps(rk: true)
            ),
            _privateKeyBuffer: privateKeyBuffer,
            _userId: userId
        )
    }

    /// Convert to dictionary for vault storage (encodes buffer as Base64URL string)
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "rawId": rawId,
            "type": type,
            "response": [
                "clientDataJSON": response.clientDataJSON,
                "attestationObject": response.attestationObject,
                "authenticatorData": response.authenticatorData,
                "publicKey": response.publicKey,
                "publicKeyAlgorithm": response.publicKeyAlgorithm,
                "transports": response.transports
            ],
            "authenticatorAttachment": authenticatorAttachment,
            "clientExtensionResults": [
                "credProps": [
                    "rk": clientExtensionResults.credProps?.rk ?? true
                ]
            ],
            "_privateKeyBuffer": _privateKeyBuffer.base64URLEncodedString(),
            "_userId": _userId
        ]
    }

    /// Create from dictionary (for reading from vault - decodes Base64URL string to buffer)
    static func fromDictionary(_ dict: [String: Any]) -> PasskeyCredential? {
        guard let id = dict["id"] as? String,
              let rawId = dict["rawId"] as? String,
              let type = dict["type"] as? String,
              let responseDict = dict["response"] as? [String: Any],
              let clientDataJSON = responseDict["clientDataJSON"] as? String,
              let attestationObject = responseDict["attestationObject"] as? String,
              let authenticatorData = responseDict["authenticatorData"] as? String,
              let publicKey = responseDict["publicKey"] as? String,
              let publicKeyAlgorithm = responseDict["publicKeyAlgorithm"] as? Int,
              let transports = responseDict["transports"] as? [String],
              let authenticatorAttachment = dict["authenticatorAttachment"] as? String,
              let privateKeyBufferB64 = dict["_privateKeyBuffer"] as? String,
              let privateKeyBuffer = Data(base64URLEncoded: privateKeyBufferB64),
              let userId = dict["_userId"] as? String else {
            return nil
        }

        let clientExtResults = dict["clientExtensionResults"] as? [String: Any]
        let credPropsDict = clientExtResults?["credProps"] as? [String: Any]
        let rk = credPropsDict?["rk"] as? Bool ?? true

        return PasskeyCredential(
            id: id,
            rawId: rawId,
            type: type,
            response: PasskeyResponse(
                clientDataJSON: clientDataJSON,
                attestationObject: attestationObject,
                authenticatorData: authenticatorData,
                publicKey: publicKey,
                publicKeyAlgorithm: publicKeyAlgorithm,
                transports: transports
            ),
            authenticatorAttachment: authenticatorAttachment,
            clientExtensionResults: PasskeyClientExtensionResults(
                credProps: PasskeyCredProps(rk: rk)
            ),
            _privateKeyBuffer: privateKeyBuffer,
            _userId: userId
        )
    }
}

/// Stored passkey record in vault (wraps credential with login record metadata)
struct PasskeyRecord: Equatable {
    let id: String                   // Record ID in vault
    let name: String                 // Display name
    let websites: [String]           // Associated domains
    let credential: PasskeyCredential
    let createdAt: Date
    let updatedAt: Date

    static func fromDictionary(_ dict: [String: Any]) -> PasskeyRecord? {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let credentialDict = dict["credential"] as? [String: Any],
              let credential = PasskeyCredential.fromDictionary(credentialDict) else {
            return nil
        }

        let websites = dict["websites"] as? [String] ?? []

        let dateFormatter = ISO8601DateFormatter()
        let createdAt = (dict["createdAt"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date()
        let updatedAt = (dict["updatedAt"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date()

        return PasskeyRecord(
            id: id,
            name: name,
            websites: websites,
            credential: credential,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

/// Request data for passkey registration (iOS 17+)
@available(iOS 17.0, *)
struct PasskeyRegistrationRequest {
    let rpId: String
    let rpName: String
    let userId: Data
    let userName: String
    let userDisplayName: String
    let challenge: Data
    let clientDataHash: Data

    /// Create from ASPasskeyCredentialRequest
    init(from request: ASPasskeyCredentialRequest) {

        // Cast to ASPasskeyCredentialIdentity to access passkey-specific properties
        guard let passkeyIdentity = request.credentialIdentity as? ASPasskeyCredentialIdentity else {
            // Fallback values if cast fails - use safe access pattern
            let fallbackUser = String(describing: request.credentialIdentity.user)
            self.rpId = "unknown"
            self.rpName = "unknown"
            self.userId = Data()
            self.userName = fallbackUser.isEmpty ? "unknown" : fallbackUser
            self.userDisplayName = fallbackUser.isEmpty ? "unknown" : fallbackUser
            self.challenge = Data()
            self.clientDataHash = request.clientDataHash
            return
        }

        // Safely access properties that might be nil at the Objective-C level
        // Using value(forKey:) provides safe access to potentially null Objective-C properties
        let rpIdValue = (passkeyIdentity as NSObject).value(forKey: "relyingPartyIdentifier") as? String ?? ""
        let userNameValue = (passkeyIdentity as NSObject).value(forKey: "userName") as? String ?? ""
        let userHandleValue = (passkeyIdentity as NSObject).value(forKey: "userHandle") as? Data ?? Data()


        self.rpId = rpIdValue.isEmpty ? "unknown" : rpIdValue
        self.rpName = rpIdValue.isEmpty ? "unknown" : rpIdValue
        self.userId = userHandleValue
        self.userName = userNameValue.isEmpty ? "unknown" : userNameValue
        self.userDisplayName = userNameValue.isEmpty ? "unknown" : userNameValue
        self.challenge = Data() // Challenge is embedded in clientDataHash
        self.clientDataHash = request.clientDataHash

    }

    init(
        rpId: String,
        rpName: String,
        userId: Data,
        userName: String,
        userDisplayName: String,
        challenge: Data,
        clientDataHash: Data
    ) {
        self.rpId = rpId
        self.rpName = rpName
        self.userId = userId
        self.userName = userName
        self.userDisplayName = userDisplayName
        self.challenge = challenge
        self.clientDataHash = clientDataHash
    }
}

/// Request data for passkey assertion (iOS 17+)
@available(iOS 17.0, *)
struct PasskeyAssertionRequest {
    let rpId: String
    let challenge: Data
    let clientDataHash: Data
    let allowedCredentialIds: [Data]

    init(
        rpId: String,
        clientDataHash: Data,
        allowedCredentialIds: [Data] = []
    ) {
        self.rpId = rpId
        self.challenge = Data()
        self.clientDataHash = clientDataHash
        self.allowedCredentialIds = allowedCredentialIds
    }
}