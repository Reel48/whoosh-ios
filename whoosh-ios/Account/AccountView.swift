import SwiftUI
import PhotosUI

/// The signed-in user's account hub: avatar + handle, Premium status (with
/// upgrade/manage link-out to web Stripe), profile editing, referrals, and
/// account details. Payments open in the browser (Apple External Purchase
/// Link); the Stripe webhook grants premium — no in-app purchase.
struct AccountView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL

    @State private var account: Account?
    @State private var loaded = false
    @State private var error: String?

    // Avatar
    @State private var photoItem: PhotosPickerItem?
    @State private var localAvatar: UIImage?
    @State private var uploadingAvatar = false

    // Premium
    @State private var showUpgrade = false
    @State private var busyBilling = false

    // Username editing
    @State private var editingUsername = false

    var body: some View {
        List {
            header
            membershipSection
            profileSection
            referralsSection
            detailsSection

            Section {
                Button("Sign out", role: .destructive) { Task { await model.signOut() } }
            }
        }
        .navigationTitle("Account")
        .task { if !loaded { await load() } }
        .refreshable { await load() }
        .sheet(isPresented: $editingUsername) {
            EditUsernameSheet(current: account?.username ?? model.currentUsername) { newName in
                model.currentUsername = newName
                Task { await load() }
            }
            .environmentObject(model)
        }
    }

    // MARK: Header (avatar + handle)

    private var header: some View {
        Section {
            HStack(spacing: 16) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        avatarImage
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(.separator), lineWidth: 0.5))
                        if uploadingAvatar {
                            ProgressView().frame(width: 72, height: 72)
                        }
                        Image(systemName: "camera.fill")
                            .font(.caption2).foregroundStyle(.white)
                            .padding(6).background(Color.brandBlue, in: Circle())
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    Text("@\(account?.username ?? model.currentUsername)")
                        .font(.title3.weight(.bold))
                    if let email = account?.auth?.email {
                        Text(email).font(.footnote).foregroundStyle(.secondary)
                    }
                    if account?.isPremium == true {
                        Label("Premium", systemImage: "star.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.whooshInk)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.whooshLime, in: Capsule())
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .onChange(of: photoItem) { _, item in
            Task { await changeAvatar(item) }
        }
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let localAvatar {
            Image(uiImage: localAvatar).resizable().scaledToFill()
        } else if let urlStr = account?.avatarUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: {
                Color(.secondarySystemBackground)
            }
        } else {
            ZStack {
                Color(.secondarySystemBackground)
                Image(systemName: "person.fill").font(.title).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Membership

    private var membershipSection: some View {
        Section("Membership") {
            HStack {
                Label("Whoosh Premium", systemImage: "star.circle.fill")
                    .foregroundStyle(account?.isPremium == true ? Color.whooshGreen : .secondary)
                Spacer()
                Text(account?.isPremium == true ? "Active" : "Free")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if account?.isPremium == true {
                Button { Task { await manageBilling() } } label: {
                    billingLabel("Manage subscription", system: "creditcard")
                }.disabled(busyBilling)
            } else {
                Button { showUpgrade = true } label: {
                    billingLabel("Upgrade to Premium", system: "sparkles", accent: true)
                }.disabled(busyBilling)
                Text("Perks for supporters. Opens secure checkout in your browser.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .confirmationDialog("Choose a plan", isPresented: $showUpgrade, titleVisibility: .visible) {
            Button("Monthly") { Task { await subscribe("monthly") } }
            Button("6 Months") { Task { await subscribe("six_months") } }
            Button("Annual") { Task { await subscribe("annual") } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func billingLabel(_ title: String, system: String, accent: Bool = false) -> some View {
        HStack {
            Label(title, systemImage: system)
                .foregroundStyle(accent ? Color.whooshInk : Color.accentColor)
            Spacer()
            if busyBilling { ProgressView() }
            else { Image(systemName: "arrow.up.forward").font(.caption).foregroundStyle(.tertiary) }
        }
    }

    // MARK: Profile

    private var profileSection: some View {
        Section("Profile") {
            Button { editingUsername = true } label: {
                HStack {
                    Label("Username", systemImage: "at")
                    Spacer()
                    Text("@\(account?.username ?? model.currentUsername)").foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
            }
        }
    }

    // MARK: Referrals

    @ViewBuilder
    private var referralsSection: some View {
        if let r = account?.referrals {
            Section("Invite friends") {
                HStack {
                    Label("Your code", systemImage: "gift.fill")
                    Spacer()
                    Text(r.code).font(.subheadline.monospaced().weight(.semibold))
                    ShareLink(item: "Join me on Whoosh — use code \(r.code)") {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                LabeledContent("Friends joined", value: "\(r.totalReferred)")
                if r.totalRewardCents > 0 {
                    LabeledContent("Bonus earned", value: Money.wb(r.totalRewardCents))
                }
            }
        }
    }

    // MARK: Account details

    private var detailsSection: some View {
        Section("Account") {
            if let auth = account?.auth {
                if let email = auth.email {
                    HStack {
                        Label("Email", systemImage: "envelope")
                        Spacer()
                        Text(email).foregroundStyle(.secondary).lineLimit(1)
                        if auth.emailVerified {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.whooshGreen)
                        }
                    }
                }
                HStack {
                    Label("Discord", systemImage: "bubble.left.and.bubble.right.fill")
                    Spacer()
                    Text(auth.hasDiscord ? "Linked" : "Not linked").foregroundStyle(.secondary)
                }
            }
            if let count = account?.achievements?.count, count > 0 {
                LabeledContent("Achievements", value: "\(count) earned")
            }
            if account?.isAdmin == true {
                NavigationLink {
                    ChatRoleAdminView()
                } label: {
                    Label("Chat Roles (Admin)", systemImage: "wrench.and.screwdriver.fill")
                }
            }
            if let error { Text(error).foregroundStyle(.bad).font(.footnote) }
        }
    }

    // MARK: Actions

    private func load() async {
        do {
            account = try await model.api.account()
            if let name = account?.username { model.currentUsername = name }
            error = nil
        } catch let e as APIError { error = e.message }
        catch { self.error = error.localizedDescription }
        loaded = true
    }

    private func changeAvatar(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        uploadingAvatar = true
        defer { uploadingAvatar = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            localAvatar = UIImage(data: data)              // instant feedback
            _ = try await model.api.uploadAvatar(imageData: data)
            await load()                                   // pick up the new avatar_url
        } catch let e as APIError { error = e.message }
        catch { self.error = error.localizedDescription }
    }

    private func subscribe(_ interval: String) async {
        busyBilling = true; defer { busyBilling = false }
        do { openURL(try await model.api.subscribe(interval: interval)) }
        catch let e as APIError { error = e.message }
        catch { self.error = error.localizedDescription }
    }

    private func manageBilling() async {
        busyBilling = true; defer { busyBilling = false }
        do { openURL(try await model.api.manageSubscription()) }
        catch let e as APIError { error = e.message }
        catch { self.error = error.localizedDescription }
    }
}

/// Change the @handle post-onboarding. Reuses the live availability check.
private struct EditUsernameSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let current: String
    let onSaved: (String) -> Void

    @State private var handle = ""
    @State private var availability: UsernameAvailability?
    @State private var checking = false
    @State private var saving = false
    @State private var error: String?
    @State private var checkTask: Task<Void, Never>?

    private var canSave: Bool {
        (availability?.available ?? false) && handle != current && !saving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("@username", text: $handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: handle) { _, _ in scheduleCheck() }
                } footer: {
                    if checking {
                        Text("Checking…")
                    } else if handle.isEmpty || handle == current {
                        Text("3–20 letters, numbers, or underscores.")
                    } else if let a = availability {
                        Text(a.available ? "✓ Available" : (a.reason ?? "Unavailable"))
                            .foregroundStyle(a.available ? Color.good : Color.bad)
                    }
                }
                if let error { Text(error).foregroundStyle(.bad).font(.footnote) }
            }
            .navigationTitle("Change username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(!canSave)
                }
            }
            .onAppear { handle = current }
        }
    }

    private func scheduleCheck() {
        checkTask?.cancel()
        availability = nil
        let candidate = handle
        guard !candidate.isEmpty, candidate != current else { return }
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

    private func save() async {
        saving = true; error = nil
        defer { saving = false }
        do {
            let profile = try await model.api.setUsername(handle)
            onSaved(profile.username)
            dismiss()
        } catch let e as APIError { error = e.message }
        catch { self.error = error.localizedDescription }
    }
}
