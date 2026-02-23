/// File: RescueLogView.swift
///
/// Demo application source for the CowCodable SDK showcase.

import CowCodable
import SwiftUI

/// Scrollable renderer for structured CowCodable rescue logs.
///
/// Purpose: surface deterministic diagnostics (rescued/skipped/failed) in a readable format.
/// Design philosophy: present structured fields directly with minimal visual noise.
/// Thread safety: read-only rendering from immutable log snapshots.
/// Deterministic behavior: entries are rendered in the exact capture order.
/// Example usage: pass `DecodeViewModel.logEntries` after each decode.
internal struct RescueLogView: View {

    // MARK: - Inputs

    internal let entries: [CowLogEntry]

    // MARK: - Body

    internal var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rescue Log")
                .font(.headline)

            if entries.isEmpty {
                Text("No rescue activity recorded.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                            logRow(entry: entry)

                            if index < entries.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
    }

    // MARK: - Subviews

    private func logRow(entry: CowLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Kind: \(entry.kind.rawValue)")
                .font(.caption)
                .fontWeight(.semibold)

            Text("Coding Path: \(entry.codingPath)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Explanation: \(entry.message)")
                .font(.subheadline)

            Text("Raw Value: \(entry.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
