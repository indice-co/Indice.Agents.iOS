//
//  Untitled.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 21/10/26.
//

import SwiftUI
import AgentsModels

struct MessageInputBox: View {
    
    @Environment(\.agentsUITheme) private var theme
    
    @FocusState private var focus

    @Binding var message: String
    @Binding var selectedAgent: AgentInfo?
    
    
    let agentsList: [AgentInfo]
    let usage: DexChatUsage?
    
    var maxCharacters: Int = 2_000
    let isSending: Bool
    let canSend  : Bool
    
    let send: () -> Void
    let stop: () -> Void
    
    private var characterCount: Int {
        message.count
    }
    
    @ViewBuilder
    private func TextInput() -> some View {
        if #available(iOS 16, macOS 14, *) {
            TextField(
                String(.screen(.session(.inputPrompt))),
                text: $message,
                axis: .vertical)
            .lineLimit(4)
        } else {
            TextEditor(text: $message)
                .overlay(content: {
                    if message.isEmpty {
                        Text(String(.screen(.session(.inputPrompt))))
                    }
                })
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                HStack(alignment: .top) {
                    TextInput()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .focused($focus)
                    
                    if false, !message.isEmpty {
                        Button(action: { message = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top,     8)
                .padding(.bottom,  4)
                .onTapGesture { focus = true }
                
                HStack {
                    AgentChoice()
                    Spacer()
                    CurrentActionButton()
                }
                
                Divider()
                
                HStack {
                    Usage()
                    Spacer()
                    CharacterCount()
                }
                .padding(.vertical,   4)
                .font(.caption2)
                .foregroundStyle(.secondary)
                
            }
            .padding(4)
            .padding(.horizontal, 8)
            .modifier(InputBackground(cornerRadius: 16))
        }
        .animation(.bouncy, value: isSending)
        .onChange(of: message) { value in
            if value.count > maxCharacters {
                message = String(value.prefix(maxCharacters))
            }
        }
    }
    
    private func AgentPill(_ agent: AgentInfo) -> some View {
        HStack {
            Image(systemName: agent.icon ?? "")
            Text(agent.name.capitalized)
            Image(systemName: "chevron.down")
        }
        .imageScale(.small)
        .foregroundStyle(.foreground)
    }
    
    @ViewBuilder
    private func AgentsList(_ agents: [AgentInfo]) -> some View {
        ForEach(Array(agentsList.enumerated()), id: \.offset) { item in
            Button(action: {
                selectedAgent = item.element
            }) {
                HStack {
                    Image(systemName: item.element.icon ?? "")
                    
                    VStack {
                        Text(item.element.name.capitalized)
                        Text(item.element.description).font(.caption)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func AgentChoice() -> some View {
        if let standard = agentsList.first {
            Menu {
                // Appears in reverse order, because the Menu inflates upwards.
                // Popup style calculation.
                AgentsList(agentsList)
            } label: {
                AgentPill(selectedAgent ?? standard)
            }
            .modifier(MenuButtonStyleProvider(tint: theme.secondaryColor))
        }
    }
    
    @ViewBuilder
    private func Usage() -> some View {
        if let usage, let maxLimit = usage.questionsLimitCount {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                HStack(spacing: 2) {
                    Text(usage.questionsUsedCount?.formatted() ?? "—")
                    Text(verbatim: " / ")
                    Text(maxLimit.formatted())
                }
            }
        }
    }
    
    private func CharacterCount() -> some View {
        HStack {
            Text(verbatim: characterCount.formatted() + " / " + maxCharacters.formatted())
            Image(systemName: "text.justify.leading")
        }
    }

    
    @ViewBuilder
    private func CurrentActionButton() -> some View {
        ActionButton(isSend: !isSending)
    }
    
    private func ActionButton(isSend: Bool) -> some View {
        Button(action: isSend ? send : stop) {
            Image(systemName: isSend ? "arrow.up" : "stop.fill")
                .padding(12)
                .background(isSend ? Color.accentColor : .gray, in: .circle)
                .shadow(radius: 8)
        }
        .modifier(ContentShapeConcentricOrRounded(fallbackCornerRadius: 14))
        .buttonStyle(.plain)
        .disabled(isSend ? !canSend : false)
        .scaleEffect(isSend ? 1 : 0.85)
    }
}

// MARK: Agent UI Helpers


// MARK: Versioning Helpers

private struct InputBackground: ViewModifier {
    
    @Environment(\.useGlassStyleIfAvailable) var useGlass
    
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        if useGlass, #available(iOS 26, macOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(.thinMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

private struct ContentShapeConcentricOrRounded: ViewModifier {
    
    let fallbackCornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.contentShape(.rect(corners: .concentric))
        } else {
            content.contentShape(.rect(cornerRadius: fallbackCornerRadius))
        }
    }
}

private struct MenuButtonStyleProvider: ViewModifier {
    
    @Environment(\.useGlassStyleIfAvailable) var useGlass
    
    let tint: Color?
    
    func body(content: Content) -> some View {
        if useGlass, #available(iOS 16, *) {
            content
                .menuStyle(.button)
                .menuOrder(.fixed)
                .buttonStyleGlassOrFallback(tint)
        } else {
            content
                .padding(8)
                .menuStyle(.borderlessButton)
                .foregroundStyle(.foreground)
                .background(tint ?? .clear, in: .capsule)
        }
    }
}

@available(iOS 17, *)
#Preview {
    
    @Previewable
    @State var message = ""
    
    let agents = [
        AgentInfo(name: "auto", icon: "sparkles"),
        AgentInfo(name: "operator", icon: "gear"),
    ]
    
    HStack {
        
        MessageInputBox(
            message: $message,
            selectedAgent: .constant(agents.first),
            agentsList: agents,
            usage: .init(
                questionsUsedCount: 5,
                questionsLimitCount: 10),
            isSending: false,
            canSend: true,
            send: { },
            stop: { })
        .padding()
        .environment(\.useGlassStyleIfAvailable, true)
        
        MessageInputBox(
            message: $message,
            selectedAgent: .constant(agents.first),
            agentsList: agents,
            usage: .init(
                questionsUsedCount: 5,
                questionsLimitCount: 10),
            isSending: false,
            canSend: true,
            send: { },
            stop: { })
        .padding()
        .environment(\.useGlassStyleIfAvailable, false)
    }
    
}
