import SwiftUI
import PhotosUI

/// First-run profile creation. Pick a unique @handle (checked live) and an
/// optional avatar, then enter the app.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel

    @State private var handle = ""
    @State private var availability: UsernameAvailability?
    @State private var checking = false
    @State private var photoItem: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var submitting = false
    @State private var error: String?
    @State private var errorShake = 0
    @State private var checkTask: Task<Void, Never>?

    private var canSubmit: Bool { (availability?.available ?? false) && !submitting }

    var body: some View {
        VStack(spacing: 24) {
            Text("Create your profile").font(.title.bold()).padding(.top, 48)

            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack {
                    Circle().fill(Color(.secondarySystemBackground)).frame(width: 110, height: 110)
                    if let data = avatarData, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: 110, height: 110).clipShape(Circle())
                    } else {
                        Image(systemName: "camera.fill").font(.title).foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { avatarData = try? await item?.loadTransferable(type: Data.self) }
            }

            VStack(alignment: .leading, spacing: 6) {
                TextField("@username", text: $handle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding().background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: handle) { _, _ in scheduleCheck() }
                if checking {
                    Text("Checking…").font(.footnote).foregroundStyle(.secondary)
                } else if let a = availability {
                    Text(a.available ? "✓ Available" : (a.reason ?? "Unavailable"))
                        .font(.footnote).foregroundStyle(a.available ? Color.good : Color.bad)
                }
            }
            .padding(.horizontal, 24)
            .shake(trigger: errorShake)

            if let error { Text(error).foregroundStyle(.bad).font(.footnote) }

            Button {
                Task { await finish() }
            } label: {
                if submitting { ProgressView().tint(Color.whooshInk) } else { Text("Enter Whoosh") }
            }
            .buttonStyle(.primaryFill)
            .opacity(canSubmit ? 1 : 0.5)
            .disabled(!canSubmit)
            .padding(.horizontal, 24)

            Button("Sign out") { Task { await model.signOut() } }
                .font(.footnote).foregroundStyle(.secondary)

            Spacer()
        }
    }

    private func scheduleCheck() {
        checkTask?.cancel()
        availability = nil
        let candidate = handle
        guard !candidate.isEmpty else { return }
        checking = true
        checkTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            if Task.isCancelled { return }
            let result = try? await model.api.usernameAvailable(candidate)
            if Task.isCancelled { return }
            availability = result
            checking = false
        }
    }

    private func finish() async {
        submitting = true; error = nil
        defer { submitting = false }
        do {
            if let data = avatarData {
                _ = try await model.api.uploadAvatar(imageData: data)
            }
            let profile = try await model.api.setUsername(handle)
            model.currentUsername = profile.username
            model.didFinishOnboarding()
        } catch let e as APIError {
            error = e.message            // "That handle is taken." on conflict
            errorShake += 1; Haptics.warning()
        } catch {
            self.error = error.localizedDescription
            errorShake += 1; Haptics.warning()
        }
    }
}

#Preview {
    OnboardingView().environmentObject(AppModel())
}
