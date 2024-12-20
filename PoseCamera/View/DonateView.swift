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
    
    @State
    private var updatesTask: Task<Void, Never>?

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

    private func listenForTransactionUpdates() {
        updatesTask = Task {
            for await transaction in Transaction.updates {
                switch transaction {
                case let .verified(transaction):
                    // 購入が確認された場合、終了処理をする
                    await transaction.finish()
                    purchased = true
                case .unverified:
                    // 購入が確認できない場合
                    break
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Text(String(localized: "donate_title"))
                    .font(.title)
                    .padding(20)
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
                        VStack {
                            Text("\(product.displayPrice) - \(product.displayName)")
                            Text(product.description)
                                .foregroundColor(Color.white)
                                .font(.caption)
                        }.foregroundColor(.white)
                            .padding()
                            .background(.blue)
                            .clipShape(Capsule())
                    }
                }
                Text(String(localized: "donate_discription"))
                    .foregroundColor(Color.gray)
                    .font(.caption)
                    .padding(20)
            }.task {
                do {
                    try await self.loadProducts()
                    listenForTransactionUpdates()
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
