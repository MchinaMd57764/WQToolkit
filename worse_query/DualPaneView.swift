import SwiftUI

struct DualPaneView: View {
    @EnvironmentObject private var l10n: L10n
    @Environment(\.dismiss) private var dismiss

    @State private var leftPath: String
    @State private var rightPath: String
    @State private var leftEntries: [FSEntry] = []
    @State private var rightEntries: [FSEntry] = []
    @State private var leftSelected: Set<String> = []
    @State private var rightSelected: Set<String> = []
    @State private var busy = false
    @State private var msg: Msg?

    init(startPath: String) {
        _leftPath = State(initialValue: startPath)
        _rightPath = State(initialValue: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                GeometryReader { geo in
                    VStack(spacing: 10) {
                        if geo.size.width >= 700 {
                            HStack(spacing: 10) {
                                pane(isLeft: true)
                                pane(isLeft: false)
                            }
                        } else {
                            VStack(spacing: 10) {
                                pane(isLeft: true)
                                pane(isLeft: false)
                            }
                        }
                        actionBar
                    }
                    .padding(12)
                }
                if busy {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    ProgressView().controlSize(.large).tint(.white)
                }
            }
            .navigationTitle(l10n.t("dual_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l10n.t("done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert(item: $msg) { m in
                Alert(title: Text(m.text), dismissButton: .default(Text(l10n.t("done"))))
            }
            .onAppear {
                load(isLeft: true)
                load(isLeft: false)
            }
        }
    }

    private func pane(isLeft: Bool) -> some View {
        let path = isLeft ? leftPath : rightPath
        let entries = isLeft ? leftEntries : rightEntries
        let selected = isLeft ? leftSelected : rightSelected

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: isLeft ? "rectangle.lefthalf.inset.filled" : "rectangle.righthalf.inset.filled")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isLeft ? Theme.blue : Theme.purple)
                Text(path == "/" ? "/" : (path as NSString).lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(l10n.t(isLeft ? "pane_left" : "pane_right"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.faint)
                if path != "/" {
                    Button {
                        setPath((path as NSString).deletingLastPathComponent, isLeft: isLeft)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.sub)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            Divider().overlay(Theme.stroke)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(entries) { e in
                        Button {
                            if e.isDir {
                                setPath(e.path, isLeft: isLeft)
                            } else {
                                toggle(e.path, isLeft: isLeft)
                            }
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: selected.contains(e.path) ? "checkmark.circle.fill" : e.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(selected.contains(e.path) ? Theme.blue : e.tint)
                                    .frame(width: 18)
                                Text(e.name)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                if e.isDir {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Theme.faint)
                                } else {
                                    Text(wqSizeString(e.size))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(Theme.faint)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 120)
            .overlay {
                if entries.isEmpty {
                    Text(l10n.t("empty_dir"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                }
            }

            Text(path)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Theme.faint)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if !leftSelected.isEmpty || !rightSelected.isEmpty {
                let movingLeft = !leftSelected.isEmpty
                let count = (leftSelected.isEmpty ? rightSelected : leftSelected).count
                let dest = movingLeft ? rightPath : leftPath
                Button {
                    transfer(fromLeft: movingLeft, move: false, dest: dest)
                } label: {
                    Text("\(l10n.t("copy_to_other")) · \(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Theme.blue))
                }
                Button {
                    transfer(fromLeft: movingLeft, move: true, dest: dest)
                } label: {
                    Text(l10n.t("move_to_other"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Theme.orange.opacity(0.9)))
                }
            } else {
                Text(l10n.t("dual_hint"))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 4)
    }

    private func setPath(_ p: String, isLeft: Bool) {
        if isLeft {
            leftPath = p
            leftSelected.removeAll()
        } else {
            rightPath = p
            rightSelected.removeAll()
        }
        load(isLeft: isLeft)
    }

    private func toggle(_ p: String, isLeft: Bool) {
        if isLeft {
            if leftSelected.contains(p) { leftSelected.remove(p) } else { leftSelected.insert(p) }
        } else {
            if rightSelected.contains(p) { rightSelected.remove(p) } else { rightSelected.insert(p) }
        }
    }

    private func load(isLeft: Bool) {
        let p = isLeft ? leftPath : rightPath
        DispatchQueue.global(qos: .userInitiated).async {
            Access.shared.grant(p)
            let list = wqReadEntries(p) ?? []
            DispatchQueue.main.async {
                if isLeft { leftEntries = list } else { rightEntries = list }
            }
        }
    }

    private func transfer(fromLeft: Bool, move: Bool, dest: String) {
        let source = fromLeft ? leftPath : rightPath
        guard source != dest else {
            msg = Msg(text: l10n.t("same_folder"))
            return
        }
        let items = Array(fromLeft ? leftSelected : rightSelected)
        guard !items.isEmpty else { return }
        busy = true
        let l = l10n
        DispatchQueue.global(qos: .userInitiated).async {
            Access.shared.grant(source)
            Access.shared.grant(dest)
            var ok = 0, bad = 0
            for src in items {
                var target = dest + "/" + (src as NSString).lastPathComponent
                var n = 1
                while FileManager.default.fileExists(atPath: target) {
                    let base = (src as NSString).lastPathComponent
                    target = dest + "/\(base) \(n)"
                    n += 1
                }
                do {
                    if move {
                        try FileManager.default.moveItem(atPath: src, toPath: target)
                    } else {
                        try FileManager.default.copyItem(atPath: src, toPath: target)
                    }
                    ok += 1
                } catch {
                    bad += 1
                }
            }
            let srcList = wqReadEntries(source) ?? []
            let dstList = wqReadEntries(dest) ?? []
            DispatchQueue.main.async {
                if fromLeft {
                    leftEntries = srcList
                    rightEntries = dstList
                    leftSelected.removeAll()
                } else {
                    rightEntries = srcList
                    leftEntries = dstList
                    rightSelected.removeAll()
                }
                busy = false
                if bad == 0 {
                    msg = Msg(text: move ? l.f("moved_ok", ok) : l.f("copied_ok", ok))
                } else {
                    msg = Msg(text: l.f("delete_partial", ok, bad))
                }
            }
        }
    }
}
