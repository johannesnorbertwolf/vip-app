import SwiftUI

struct PhotoYearsView: View {
    var body: some View {
        Loader(load: Scraper.photoYears) { years in
            List {
                Section("Latest albums") { LatestAlbums() }
                Section("Archive") {
                    ForEach(years) { y in
                        NavigationLink(y.title) { PhotoMonthsView(year: y) }
                    }
                }
            }
        }
        .navigationTitle("Photos")
    }
}

struct LatestAlbums: View {
    var body: some View {
        Loader(load: { try await Scraper.albums(Scraper.photosRoot) }) { albums in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(albums) { a in
                        NavigationLink { AlbumView(album: a) } label: { AlbumTile(album: a).frame(width: 220) }
                            .buttonStyle(.plain)
                    }
                }.padding(.vertical, 4)
            }
            // Only sideways: stops the strip from also bouncing up and down inside the list.
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .frame(height: 190)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0))
    }
}

struct PhotoMonthsView: View {
    let year: PhotoFolder
    var body: some View {
        Loader(load: { try await Scraper.photoMonths(year: year.path) }) { months in
            List(months) { m in NavigationLink(m.title) { AlbumsView(folder: m) } }
        }
        .navigationTitle(year.title)
    }
}

struct AlbumsView: View {
    let folder: PhotoFolder
    var body: some View {
        Loader(load: { try await Scraper.albums(folder.path) }) { albums in
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(albums) { a in
                        NavigationLink { AlbumView(album: a) } label: { AlbumTile(album: a) }.buttonStyle(.plain)
                    }
                }.padding()
            }
            .overlay { if albums.isEmpty { ContentUnavailableView("No albums", systemImage: "photo") } }
        }
        .navigationTitle(folder.title)
    }
}

struct AlbumTile: View {
    let album: Album
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.secondary.opacity(0.12)
                .aspectRatio(3 / 2, contentMode: .fit)
                .overlay { AsyncImage(url: album.coverURL) { $0.resizable().scaledToFill() } placeholder: { ProgressView() } }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(album.title).font(.subheadline.weight(.semibold)).lineLimit(1)
            Text([album.date, album.count].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct AlbumView: View {
    let album: Album
    @State private var selected: PhotoIndex?

    var body: some View {
        Loader(load: { try await Scraper.album(album.path) }) { detail in
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 2)], spacing: 2) {
                    ForEach(Array(detail.photos.enumerated()), id: \.offset) { i, url in
                        Color.secondary.opacity(0.12)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay { AsyncImage(url: thumb(url)) { $0.resizable().scaledToFill() } placeholder: { Color.clear } }
                            .clipped()
                            .onTapGesture { selected = PhotoIndex(index: i) }
                    }
                }
            }
            .fullScreenCover(item: $selected) { s in PhotoPager(photos: detail.photos, start: s.index) }
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    func thumb(_ url: URL) -> URL { URL(string: url.absoluteString + "?tr=w-300,h-300,fo-auto") ?? url }
}

struct PhotoIndex: Identifiable { var id: Int { index }; let index: Int }

/// One full-size photo that zooms with a pinch or a double tap (up to 5x).
struct ZoomablePhoto: View {
    let url: URL
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        AsyncImage(url: url) { img in
            img.resizable().scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnifyGesture()
                        .onChanged { v in scale = min(max(lastScale * v.magnification, 1), 5) }
                        .onEnded { _ in
                            withAnimation { if scale < 1.05 { scale = 1 } }
                            lastScale = scale
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation { scale = scale > 1 ? 1 : 2.5 }
                    lastScale = scale
                }
        } placeholder: {
            ProgressView().tint(.white)
        }
    }
}

struct PhotoPager: View {
    let photos: [URL]
    @State var start: Int
    @State private var current: UIImage?
    @State private var toast: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $start) {
                ForEach(Array(photos.enumerated()), id: \.offset) { i, url in
                    ZoomablePhoto(url: url).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Text("\(start + 1) / \(photos.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.title).symbolRenderingMode(.hierarchical).foregroundStyle(.white)
                    }.accessibilityLabel("Close")
                }
                Spacer()
                if let toast {
                    Text(toast).font(.subheadline.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.opacity)
                }
                HStack(spacing: 40) {
                    if let img = current {
                        ShareLink(item: Image(uiImage: img), preview: SharePreview("VIP photo", image: Image(uiImage: img))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button { save(img) } label: { Label("Save", systemImage: "square.and.arrow.down") }
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .font(.headline).foregroundStyle(.white).labelStyle(.titleAndIcon)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(.white.opacity(0.15), in: Capsule())
            }
            .padding()
        }
        .task(id: start) { await loadCurrent() }
    }

    /// Downloads the full-size photo shown, so it can be shared or saved.
    func loadCurrent() async {
        current = nil
        guard photos.indices.contains(start),
              let (data, _) = try? await URLSession.shared.data(from: photos[start]) else { return }
        current = UIImage(data: data)
    }

    func save(_ img: UIImage) {
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        withAnimation { toast = "Saved to Photos" }
        Task { try? await Task.sleep(for: .seconds(1.5)); withAnimation { toast = nil } }
    }
}
