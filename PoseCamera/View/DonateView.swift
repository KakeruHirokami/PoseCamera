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
    
    @State
    private var loading: Bool = false

    private func loadProducts() async throws {
        products = try await Product.products(for: productIds)
        products.sort(by: { (p0, p1) -> Bool in
            return p0.price < p1.price
        })
    }
    
    private func purchase(_ product: Product) async throws {
        let result: Product.PurchaseResult = try await product.purchase()
        loading = true
        switch result {
            case let .success(.verified(transaction)):
                // Successful purchase
                await transaction.finish()
                purchased = true
                loading = false
            case .success(.unverified):
                // Successful purchase but transaction/receipt can't be verified
                // Could be a jailbroken phone
                loading = false
                break
            case .pending:
                // Transaction waiting on SCA (Strong Customer Authentication) or
                // approval from Ask to Buy
                loading = false
                break
            case .userCancelled:
                loading = false
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

    private func LoadingView() -> some View {
        ZStack {
            Color(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.75))
            VStack(alignment: .center, spacing: 40) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(x: 1.8, y: 1.8, anchor: .center)
                    .frame(width: 1.8 * 20, height: 1.8 * 20)
                    .padding(.top, 100)
                
                Text(String(localized: "Purchase processing in progress."))
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: 300)
                Text(String(localized: "Do not operate the screen."))
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: 300)
                
                Spacer()
            }
        }
        .opacity(loading ? 1.0 : 0)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Text(String(localized: "Give me some energy!!"))
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
                Text(String(localized: "PoseCamera is free to use, but developing, maintaining, and publishing the app involves costs."))
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
            if loading {
                LoadingView()
            }
        }
    }
}
