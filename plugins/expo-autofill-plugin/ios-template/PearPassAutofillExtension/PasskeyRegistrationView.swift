//
//  PasskeyRegistrationView.swift
//  PearPassAutoFillExtension
//
//  UI for passkey registration flow
//

import SwiftUI
import AuthenticationServices
import CryptoKit

@available(iOS 17.0, *)
struct PasskeyRegistrationView: View {
    let request: PasskeyRegistrationRequest
    let presentationWindow: UIWindow?
    let onComplete: (PasskeyCredential, Data, Data) -> Void  // credential, attestationObject, credentialId
    let onCancel: () -> Void
    let onVaultClientCreated: ((PearPassVaultClient) -> Void)?

    @StateObject private var viewModel = ExtensionViewModel()
    @State private var vaultClient: PearPassVaultClient?
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedVault: Vault?
    @State private var currentStep: RegistrationStep = .initializing

    // User initialization state
    @State private var hasPasswordSet: Bool = false
    @State private var isLoggedIn: Bool = false

    enum RegistrationStep {
        case initializing
        case masterPassword
        case vaultSelection
        case vaultPassword
        case confirming
        case saving
    }

    var body: some View {
        ZStack {
            SharedBackgroundView()

            VStack(spacing: 0) {
                switch currentStep {
                case .initializing:
                    loadingView

                case .masterPassword:
                    MasterPasswordView(
                        viewModel: viewModel,
                        onCancel: onCancel,
                        vaultClient: vaultClient,
                        presentationWindow: presentationWindow
                    )

                case .vaultSelection:
                    VaultSelectionView(
                        viewModel: viewModel,
                        onCancel: onCancel,
                        vaultClient: vaultClient
                    )

                case .vaultPassword:
                    if let vault = selectedVault {
                        VaultPasswordView(
                            viewModel: viewModel,
                            vault: vault,
                            onCancel: onCancel,
                            vaultClient: vaultClient
                        )
                    }

                case .confirming:
                    confirmationView

                case .saving:
                    savingView
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
        .onAppear {
            initialize()
        }
        .onChange(of: viewModel.currentFlow) { newFlow in
            handleFlowChange(newFlow)
        }
    }

    // MARK: - Views

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: Constants.Colors.primaryGreen))

            Text(NSLocalizedString("Loading...", comment: "Loading indicator"))
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private var confirmationView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                CancelHeader {
                    onCancel()
                }

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(height: 40)

                        // Passkey icon
                        ZStack {
                            RoundedRectangle(cornerRadius: Constants.Layout.mediumCornerRadius)
                                .fill(Constants.Colors.vaultIconBackground)
                                .frame(width: 80, height: 80)

                            Image(systemName: "person.badge.key.fill")
                                .font(.system(size: 36))
                                .foregroundColor(Constants.Colors.primaryGreen)
                        }

                        VStack(spacing: 8) {
                            Text(NSLocalizedString("Create Passkey", comment: "Create passkey title"))
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)

                            Text(String(format: NSLocalizedString("Save a passkey for %@", comment: "Save passkey description"), request.rpId))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }

                        // User info card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .foregroundColor(Constants.Colors.primaryGreen)
                                    .frame(width: 24)
                                Text(request.userName)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }

                            HStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .foregroundColor(Constants.Colors.primaryGreen)
                                    .frame(width: 24)
                                Text(request.rpId)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            if let vault = selectedVault {
                                HStack(spacing: 12) {
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundColor(Constants.Colors.primaryGreen)
                                        .frame(width: 24)
                                    Text(String(format: NSLocalizedString("Saving to: %@", comment: "Saving to vault"), vault.name))
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Layout.mediumCornerRadius)
                                .fill(Constants.Colors.credentialBackground)
                        )

                        // Error message
                        if let error = error {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        Spacer()
                            .frame(height: 20)

                        // Actions
                        VStack(spacing: 12) {
                            Button(action: createPasskey) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                                                .fill(Constants.Colors.primaryGreen)
                                        )
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "key.fill")
                                        Text(NSLocalizedString("Save Passkey", comment: "Save passkey button"))
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                                            .fill(Constants.Colors.primaryGreen)
                                    )
                                }
                            }
                            .disabled(isLoading || selectedVault == nil)
                            .opacity(isLoading || selectedVault == nil ? 0.6 : 1.0)

                            Button(action: onCancel) {
                                Text(NSLocalizedString("Cancel", comment: "Cancel button"))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Constants.Colors.primaryGreen)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                                            .stroke(Constants.Colors.primaryGreen, lineWidth: 2)
                                    )
                            }
                        }

                        Spacer()
                            .frame(height: 30)
                    }
                    .padding(.horizontal, Constants.Layout.horizontalPadding)
                }
            }
        }
    }

    private var savingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: Constants.Colors.primaryGreen))

            Text(NSLocalizedString("Creating passkey...", comment: "Creating passkey indicator"))
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Initialization

    private func initialize() {

        guard vaultClient == nil else {
            return
        }

        // Initialize with readOnly: false to allow passkey storage
        let client = PearPassVaultClient(debugMode: true, readOnly: false)

        vaultClient = client

        onVaultClientCreated?(client)

        Task {
            do {
                try await client.waitForInitialization()
                await initializeUser()
            } catch {
                await MainActor.run {
                    self.error = NSLocalizedString("Failed to initialize", comment: "Initialization error")
                }
            }
        }
    }

    private func initializeUser() async {
        guard let client = vaultClient else { return }

        do {
            let vaultsStatusRes = try await client.vaultsGetStatus()
            let activeVaultStatusRes = try await client.activeVaultGetStatus()
            let masterPasswordEncryption = try await client.getMasterPasswordEncryption(vaultStatus: vaultsStatusRes)

            let passwordSet = masterPasswordEncryption != nil &&
                             masterPasswordEncryption?.ciphertext != nil &&
                             masterPasswordEncryption?.nonce != nil &&
                             masterPasswordEncryption?.salt != nil

            let loggedIn = vaultsStatusRes.isInitialized && !vaultsStatusRes.isLocked

            await MainActor.run {
                self.hasPasswordSet = passwordSet
                self.isLoggedIn = loggedIn

                if !passwordSet {
                    // Cannot create passkey without master password
                    self.error = NSLocalizedString("Please set up PearPass first", comment: "Setup required error")
                    self.currentStep = .confirming
                } else if !loggedIn {
                    self.viewModel.currentFlow = .masterPassword
                    self.currentStep = .masterPassword
                } else {
                    self.viewModel.currentFlow = .vaultSelection
                    self.currentStep = .vaultSelection
                }
            }
        } catch {
            await MainActor.run {
                self.error = NSLocalizedString("Failed to check authentication status", comment: "Auth check error")
                self.currentStep = .confirming
            }
        }
    }

    // MARK: - Flow Handling

    private func handleFlowChange(_ flow: AuthFlow) {
        switch flow {
        case .masterPassword:
            currentStep = .masterPassword
        case .vaultSelection:
            currentStep = .vaultSelection
        case .vaultPassword(let vault):
            selectedVault = vault
            currentStep = .vaultPassword
        case .credentialsList(let vault):
            // User has unlocked a vault, proceed to confirmation
            selectedVault = vault
            currentStep = .confirming
        default:
            break
        }
    }

    // MARK: - Passkey Creation

    private func createPasskey() {
        guard let vault = selectedVault else {
            error = NSLocalizedString("Please select a vault", comment: "Vault selection required error")
            return
        }

        isLoading = true
        error = nil
        currentStep = .saving

        Task {
            do {
                let credential = try await generateAndSavePasskey(vault: vault)
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                    self.currentStep = .confirming
                }
            }
        }
    }

    private func generateAndSavePasskey(vault: Vault) async throws -> PasskeyCredential {

        // 1. Generate key pair
        let privateKey = PasskeyCrypto.generatePrivateKey()
        let privateKeyB64 = PasskeyCrypto.exportPrivateKey(privateKey)
        guard let privateKeyData = Data(base64URLEncoded: privateKeyB64) else {
            throw PearPassVaultError.unknown("Failed to decode private key")
        }
        let publicKeyB64 = PasskeyCrypto.exportPublicKey(privateKey.publicKey)


        // 2. Generate credential ID
        let (credentialIdData, credentialIdB64) = PasskeyCrypto.generateCredentialId()


        // 3. Build authenticator data
        let authData = AuthenticatorDataBuilder.buildForRegistration(
            rpId: request.rpId,
            credentialId: credentialIdData,
            publicKey: privateKey.publicKey
        )


        // 4. Build attestation object
        let attestationObject = AuthenticatorDataBuilder.encodeAttestationObject(authData: authData)


        // 5. Build client data JSON (for storage reference)
        let clientDataJSON = AuthenticatorDataBuilder.buildClientDataJSONForRegistration(
            challenge: request.challenge,
            origin: "https://\(request.rpId)"
        )

        // 6. Create the credential response
        let response = PasskeyResponse(
            clientDataJSON: clientDataJSON.base64URLEncodedString(),
            attestationObject: attestationObject.base64URLEncodedString(),
            authenticatorData: authData.base64URLEncodedString(),
            publicKey: publicKeyB64,
            publicKeyAlgorithm: -7,  // ES256
            transports: ["internal"]
        )

        // 7. Create the full credential (matches browser extension format - no rpId/userName in credential)
        let credential = PasskeyCredential.create(
            credentialId: credentialIdB64,
            response: response,
            privateKeyBuffer: privateKeyData,
            userId: request.userId.base64URLEncodedString()
        )


        // 8. Save to vault
        if let client = vaultClient {
            do {
                // Ensure the vault is active before saving
                // This follows the same pattern as CredentialsListView
                try await activateVaultIfNeeded(client: client, vault: vault)

                let recordId = try await client.savePasskey(
                    vaultId: vault.id,
                    credential: credential,
                    name: request.rpName,
                    userName: request.userName,
                    websites: [request.rpId]
                )
                print("[PasskeyRegistrationView] Passkey saved successfully with recordId: \(recordId)")
            } catch {
                // Log the error for debugging but continue - the credential is generated
                print("[PasskeyRegistrationView] ERROR saving passkey to vault: \(error.localizedDescription)")
            }
        }

        // 9. Complete registration
        await MainActor.run {
            onComplete(credential, attestationObject, credentialIdData)
        }

        return credential
    }

    /// Activates the vault if it's not already active
    /// This follows the same pattern as CredentialsListView.loadAllCredentials()
    private func activateVaultIfNeeded(client: PearPassVaultClient, vault: Vault) async throws {
        // Check if the active vault is already the one we need
        let activeStatus = try await client.activeVaultGetStatus()
        if activeStatus.isInitialized && !activeStatus.isLocked {
            // We could check if it's the same vault, but for simplicity we'll re-initialize
        }

        // Check if vault is protected (has its own password)
        let isProtected = try await client.checkVaultIsProtected(vaultId: vault.id)

        if isProtected {
            // For protected vaults, use getVaultById which handles password-protected vaults
            let vaultData = try await client.getVaultById(vaultId: vault.id)
        } else {
            // For unprotected vaults, use master encryption key
            let masterEncryptionData = try await client.vaultsGet(key: "masterEncryption")
            guard let hashedPassword = masterEncryptionData["hashedPassword"] as? String else {
                throw PearPassVaultError.unknown("No hashed password available in master encryption")
            }

            let decryptedKeyResult = try await client.decryptVaultKey(
                ciphertext: masterEncryptionData["ciphertext"] as? String ?? "",
                nonce: masterEncryptionData["nonce"] as? String ?? "",
                hashedPassword: hashedPassword
            )

            guard let encryptionKey = decryptedKeyResult?["value"] as? String ??
                                     decryptedKeyResult?["key"] as? String ??
                                     decryptedKeyResult?["data"] as? String else {
                throw PearPassVaultError.decryptionFailed
            }

            _ = try await client.activeVaultInit(id: vault.id, encryptionKey: encryptionKey)
        }
    }
}
