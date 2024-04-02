//
//  VisualEffectBackground.swift
//  remember
//
//  Created by Bogdan Popa on 23/12/2019.
//  Copyright © 2019-2024 CLEARTYPE SRL. All rights reserved.
//

import Foundation
import SwiftUI

struct VisualEffectBackground: NSViewRepresentable {
  typealias NSViewType = NSVisualEffectView

  private let blendingMode: NSVisualEffectView.BlendingMode
  private let material: NSVisualEffectView.Material
  private let state: NSVisualEffectView.State

  fileprivate init(
    blendingMode: NSVisualEffectView.BlendingMode,
    material: NSVisualEffectView.Material,
    state: NSVisualEffectView.State
  ) {
    self.blendingMode = blendingMode
    self.material = material
    self.state = state
  }

  func makeNSView(context: Context) -> NSViewType {
    return NSVisualEffectView()
  }

  func updateNSView(_ nsView: NSViewType, context: Context) {
    nsView.blendingMode = blendingMode
    nsView.material = material
    nsView.state = state
  }
}

extension View {
  func visualEffect(
    blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
    material: NSVisualEffectView.Material = .popover,
    state: NSVisualEffectView.State = .active
  ) -> some View {
    background(
      VisualEffectBackground(
        blendingMode: blendingMode,
        material: material,
        state: state
      )
    )
  }
}
