import Foundation

/// App configuration. None of these are secrets — the Supabase anon key is
/// publishable and the URLs are public.
enum Config {
    /// Deployed backend origin (the api/v1 routes live here).
    /// For local testing against `npm run dev`, the iOS Simulator can reach the
    /// Mac at `http://localhost:3000` (and that dev server uses local Supabase,
    /// so also point `supabaseURL` at the local stack to keep the token issuer
    /// and verifier consistent).
    static let apiBaseURL = URL(string: "https://whoosh.business")!

    /// Supabase project URL.
    static let supabaseURL = URL(string: "https://yjmohosxtemjamwrsffw.supabase.co")!

    /// Supabase anon (publishable) key — sent as the `apikey` header to GoTrue.
    /// Safe to ship in the app binary.
    static let supabaseAnonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlqbW9ob3N4dGVtamFtd3JzZmZ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5Njg3NzQsImV4cCI6MjA5NTU0NDc3NH0.1vKzHNxc49tluMauKNbL9kbOmol6eljUWUgIVE_26lI"
}
