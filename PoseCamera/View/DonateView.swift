//
//  DonateView.swift
//  PoseCamera
//
//  Created by 広上駆 on 2024/12/15.
//
import SwiftUI
import StoreKit
import Confetti

struct DonateView: View {
    let productIds = ["tip.s", "tip.m", "tip.l", "tip.xl"]
    private var updates: Task<Void, Never>? = nil
    
    @State
    private var products: [Product] = []
    
    @State
    private var purchased: Bool = false

    private func loadProducts() async throws {
        products = try await Product.products(for: productIds)
        products.sort(by: { (p0, p1) -> Bool in
            return p0.price < p1.price
        })
    }
    
    private func purchase(_ product: Product) async throws {
        let result: Product.PurchaseResult = try await product.purchase()
        switch result {
            case let .success(.verified(transaction)):
                // Successful purchase
                await transaction.finish()
                purchased = true
            case .success(.unverified):
                // Successful purchase but transaction/receipt can't be verified
                // Could be a jailbroken phone
                break
            case .pending:
                // Transaction waiting on SCA (Strong Customer Authentication) or
                // approval from Ask to Buy
                break
            case .userCancelled:
                // ^^^
                break
            @unknown default:
                break
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                ForEach(self.products) { product in
                    Button {
                        Task {
                            do {
                                try await self.purchase(product)
                            } catch {
                                print(error)
                            }
                        }
                    } label: {
                        Text("\(product.displayPrice) - \(product.displayName)")
                            .foregroundColor(.white)
                            .padding()
                            .background(.blue)
                            .clipShape(Capsule())
                    }
                }
                Text("PoseCameraは無料ですが、アプリの開発・メンテナンス・公開には費用がかかります。気に入っていただけたら、ぜひチップをお願いします。")
                    .foregroundColor(Color.gray)
                    .font(.caption)
                    .padding(20)
            }.task {
                do {
                    try await self.loadProducts()
                } catch {
                    print(error)
                }
            }
            if purchased {
                ConfettiView()
            }
        }
    }
}
