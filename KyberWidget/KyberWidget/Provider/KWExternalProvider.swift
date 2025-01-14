//
//  KWExternalProvider.swift
//  KyberWidget
//
//  Created by Manh Le on 27/8/18.
//  Copyright © 2018 kyber.network. All rights reserved.
//


import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore
import TrustCore
import JavaScriptKit

public class KWExternalProvider: NSObject {

  let keystore: KWKeystore
  let web3Swift: KWWeb3Swift
  let knCustomRPC: KWCustomRPC!
  let networkAddress: Address!
  let payAddress: Address!
  let generalProvider: KWGeneralProvider
  let network: KWEnvironment

  var minTxCount: Int = 0

  public init(keystore: KWKeystore, network: KWEnvironment) {
    print("Endpoint: \(network.customRPC?.endpoint ?? "")")
    self.keystore = keystore
    let customRPC: KWCustomRPC = network.customRPC!
    self.knCustomRPC = customRPC
    self.networkAddress = Address(string: customRPC.networkAddress)!
    self.payAddress = Address(string: customRPC.payAddress)!
    self.generalProvider = KWGeneralProvider(network: network)
    self.network = network
    self.minTxCount = 0
    self.web3Swift = KWWeb3Swift(url: URL(string: network.customRPC?.endpoint ?? "")!)
    super.init()
    self.web3Swift.start()
  }

  // MARK: Balance
  public func getETHBalance(address: String, completion: @escaping (Result<BigInt, AnyError>) -> Void) {
    self.generalProvider.getETHBalanace(
      for: address,
      completion: completion
    )
  }

  public func getTokenBalance(for contract: Address, address: Address, completion: @escaping (Result<BigInt, AnyError>) -> Void) {
    self.generalProvider.getTokenBalance(
      for: address,
      contract: contract,
      completion: completion
    )
  }

  // MARK: Transaction
  public func getTransactionCount(for address: String, completion: @escaping (Result<Int, AnyError>) -> Void) {
    DispatchQueue.global(qos: .background).async {
      self.generalProvider.getTransactionCount(
      for: address) { [weak self] result in
        DispatchQueue.main.async {
          guard let `self` = self else { return }
          switch result {
          case .success(let txCount):
            self.minTxCount = max(self.minTxCount, txCount)
            completion(.success(txCount))
          case .failure(let error):
            completion(.failure(error))
          }
        }
      }
    }
  }

  public func transfer(transaction: KWTransaction, completion: @escaping (Result<String, AnyError>) -> Void) {
    print("Transfer: Getting transaction count")
    self.getTransactionCount(for: transaction.account?.address.description ?? "") { [weak self] txCountResult in
      guard let `self` = self else { return }
      switch txCountResult {
      case .success:
        print("Transfer: Success getting transaction count")
        self.requestDataForTokenTransfer(transaction, completion: { [weak self] dataResult in
          guard let `self` = self else { return }
          switch dataResult {
          case .success(let data):
            print("Transfer: Success getting data for transfer")
            self.signTransactionData(from: transaction, isPay: false, nonce: self.minTxCount, data: data, completion: { signResult in
              switch signResult {
              case .success(let signData):
                print("Transfer: Success signed transaction")
                DispatchQueue.global(qos: .background).async {
                  self.generalProvider.sendSignedTransactionData(signData, completion: { [weak self] result in
                    DispatchQueue.main.async {
                      guard let `self` = self else { return }
                      print("Transfer: Done sending transfer request")
                      if case .success = result { self.minTxCount += 1 }
                      completion(result)
                    }
                  })
                }
              case .failure(let error):
                print("Transfer: Failed signed transaction")
                completion(.failure(error))
              }
            })
          case .failure(let error):
            print("Transfer: Failed getting data for transfer")
            completion(.failure(error))
          }
        })
      case .failure(let error):
        print("Transfer: Failed getting transaction count")
        completion(.failure(error))
      }
    }
  }

  public func exchange(exchange: KWTransaction, completion: @escaping (Result<String, AnyError>) -> Void) {
    print("Swap: getting transaction count")
    self.getTransactionCount(for: exchange.account?.address.description ?? "") { [weak self] txCountResult in
      guard let `self` = self else { return }
      switch txCountResult {
      case .success:
        print("Swap: Success getting transaction count")
        self.requestDataForTokenExchange(exchange, completion: { [weak self] dataResult in
          guard let `self` = self else { return }
          switch dataResult {
          case .success(let data):
            print("Swap: Success getting data for swapping")
            self.signTransactionData(from: exchange, isPay: false, nonce: self.minTxCount, data: data, completion: { signResult in
              switch signResult {
              case .success(let signData):
                print("Swap: Success signed transaction")
                DispatchQueue.global(qos: .background).async {
                  self.generalProvider.sendSignedTransactionData(signData, completion: { [weak self] result in
                    DispatchQueue.main.async {
                      guard let `self` = self else { return }
                      print("Swap: Done sending swap transaction")
                      if case .success = result { self.minTxCount += 1 }
                      completion(result)
                    }
                  })
                }
              case .failure(let error):
                print("Swap: Failed signed transaction")
                completion(.failure(error))
              }
            })
          case .failure(let error):
            print("Swap: Failed getting data for swapping")
            completion(.failure(AnyError(error)))
          }
        })
      case .failure(let error):
        print("Swap: Failed getting transaction count")
        completion(.failure(AnyError(error)))
      }
    }
  }

  public func pay(transaction: KWTransaction, completion: @escaping (Result<String, AnyError>) -> Void) {
    print("Pay: getting transaction count")
    self.getTransactionCount(for: transaction.account?.address.description ?? "") { [weak self] txCountResult in
      guard let `self` = self else { return }
      switch txCountResult {
      case .success:
        print("Pay: Success getting transaction count")
        self.requestDataForPay(transaction, completion: { [weak self] dataResult in
          guard let `self` = self else { return }
          switch dataResult {
          case .success(let data):
            print("Pay: Success getting data for paying")
            self.signTransactionData(from: transaction, isPay: true, nonce: self.minTxCount, data: data, completion: { signResult in
              switch signResult {
              case .success(let signData):
                print("Pay: Success signed transaction")
                DispatchQueue.global(qos: .background).async {
                  self.generalProvider.sendSignedTransactionData(signData, completion: { [weak self] result in
                    DispatchQueue.main.async {
                      guard let `self` = self else { return }
                      print("Swap: Done sending pay transaction")
                      if case .success = result { self.minTxCount += 1 }
                      completion(result)
                    }
                  })
                }
              case .failure(let error):
                print("Pay: Failed signed transaction")
                completion(.failure(error))
              }
            })
          case .failure(let error):
            print("Pay: Failed getting data for paying")
            completion(.failure(AnyError(error)))
          }
        })
      case .failure(let error):
        print("Pay: Failed getting transaction count")
        completion(.failure(AnyError(error)))
      }
    }
  }

  // If the value returned > 0 consider as allowed
  // should check with the current send amount, however the limit is likely set as very big
  public func getAllowance(token: KWTokenObject, address: Address, isPay: Bool, completion: @escaping (Result<BigInt, AnyError>) -> Void) {
    self.generalProvider.getAllowance(
      for: token,
      address: address,
      networkAddress: isPay ? self.payAddress : self.networkAddress,
      completion: completion
    )
  }

  public func resetAllowanceIfNeeded(exchangeTransaction: KWTransaction, isPay: Bool, allowance: BigInt, completion: @escaping (Result<Int?, AnyError>) -> Void) {
    if allowance >= exchangeTransaction.amountFrom {
      completion(.success(nil))
      return
    }
    DispatchQueue.global(qos: .background).async {
      self.generalProvider.approve(
        token: exchangeTransaction.from,
        account: exchangeTransaction.account!,
        keystore: self.keystore,
        networkAddress: isPay ? self.payAddress : self.networkAddress,
        networkID: self.network.chainID,
        value: BigInt(0),
        usedNonce: nil
      ) { [weak self] result in
        DispatchQueue.main.async {
          guard let `self` = self else { return }
          switch result {
          case .success(let txCount):
            self.minTxCount = txCount
            completion(.success(txCount))
          case .failure(let error):
            completion(.failure(error))
          }
        }
      }
    }
  }

  // Encode function, get transaction count, sign transaction, send signed data
  public func sendApproveERC20Token(exchangeTransaction: KWTransaction, isPay: Bool, usedNonce: Int?, completion: @escaping (Result<Bool, AnyError>) -> Void) {
    DispatchQueue.global(qos: .background).async {
      self.generalProvider.approve(
        token: exchangeTransaction.from,
        account: exchangeTransaction.account!,
        keystore: self.keystore,
        networkAddress: isPay ? self.payAddress : self.networkAddress,
        networkID: self.network.chainID,
        value: BigInt(2).power(255),
        usedNonce: usedNonce
      ) { [weak self] result in
        DispatchQueue.main.async {
          guard let `self` = self else { return }
          switch result {
          case .success(let txCount):
            self.minTxCount = txCount
            completion(.success(true))
          case .failure(let error):
            completion(.failure(error))
          }
        }
      }
    }
  }

  // MARK: Rate
  public func getExpectedRate(from: KWTokenObject, to: KWTokenObject, amount: BigInt, completion: @escaping (Result<(BigInt, BigInt), AnyError>) -> Void) {
    DispatchQueue.global(qos: .background).async {
      self.generalProvider.getExpectedRate(
        from: from,
        to: to,
        amount: amount) { [weak self] result in
        DispatchQueue.main.async {
          guard let _ = self else { return }
          switch result {
          case .success(let data):
            let expectedRate = data.0 / BigInt(10).power(18 - to.decimals)
            let slippageRate = data.1 / BigInt(10).power(18 - to.decimals)
            completion(.success((expectedRate, slippageRate)))
          case .failure(let error):
            completion(.failure(error))
          }
        }
      }
    }
  }

  // MARK: Estimate Gas
  public func getTransferEstimateGasLimit(for transaction: KWTransaction, completion: @escaping (Result<BigInt, AnyError>) -> Void) {
    let defaultGasLimit: BigInt = {
      return KWGasConfiguration.calculateDefaultGasLimitTransfer(token: transaction.from)
    }()
    DispatchQueue.global(qos: .background).async {
      self.requestDataForTokenTransfer(transaction) { [weak self] result in
        guard let `self` = self else { return }
        DispatchQueue.main.async {
          switch result {
          case .success(let data):
            self.estimateGasLimit(
              from: transaction.account?.address.description ?? transaction.destWallet,
              to: transaction.from.isETH ? transaction.destWallet : transaction.to.address,
              gasPrice: transaction.gasPrice ?? KWGasConfiguration.gasPriceFast,
              value: transaction.from.isETH ? transaction.amountFrom : BigInt(0),
              data: data,
              defaultGasLimit: defaultGasLimit,
              completion: completion
            )
          case .failure(let error):
            completion(.failure(error))
          }
        }
      }
    }
  }

  public func getSwapEstimateGasLimit(for transaction: KWTransaction, completion: @escaping (Result<BigInt, AnyError>) -> Void) {
    let value: BigInt = transaction.from.isETH ? transaction.amountFrom : BigInt(0)

    let defaultGasLimit: BigInt = {
      return KWGasConfiguration.calculateGasLimit(from: transaction.from, to: transaction.to, isPay: false)
    }()

    DispatchQueue.global(qos: .background).async {
      self.requestDataForTokenExchange(transaction) { [weak self] dataResult in
        guard let `self` = self else { return }
        DispatchQueue.main.async {
          switch dataResult {
          case .success(let data):
            self.estimateGasLimit(
              from: transaction.account?.address.description ?? transaction.destWallet,
              to: self.networkAddress.description,
              gasPrice: transaction.gasPrice ?? KWGasConfiguration.gasPriceFast,
              value: value,
              data: data,
              defaultGasLimit: defaultGasLimit,
              completion: completion
            )
          case .failure(let error):
            completion(.failure(error))
          }
        }
      }
    }
  }

  public func getPayEstimateGasLimit(for transaction: KWTransaction, completion: @escaping (Result<BigInt, AnyError>) -> Void) {
    let value: BigInt = transaction.from.isETH ? transaction.amountFrom : BigInt(0)
    let defaultGasLimit: BigInt = {
      return KWGasConfiguration.calculateGasLimit(from: transaction.from, to: transaction.to, isPay: true)
    }()
    DispatchQueue.global(qos: .background).async {
      self.requestDataForPay(transaction) { [weak self] dataResult in
        guard let `self` = self else { return }
        DispatchQueue.main.async {
          switch dataResult {
          case .success(let data):
            self.estimateGasLimit(
              from: transaction.account?.address.description ?? transaction.destWallet,
              to: self.payAddress.description,
              gasPrice: transaction.gasPrice ?? KWGasConfiguration.gasPriceFast,
              value: value,
              data: data,
              defaultGasLimit: defaultGasLimit,
              completion: completion
            )
          case .failure(let error):
            completion(.failure(error))
          }
        }
      }
    }
  }

  public func estimateGasLimit(from: String, to: String?, gasPrice: BigInt, value: BigInt, data: Data, defaultGasLimit: BigInt, completion: @escaping (Result<BigInt, AnyError>) -> Void) {
    let request = KWEstimateGasLimitRequest(
      from: from,
      to: to,
      value: value,
      data: data,
      gasPrice: gasPrice
    )
    NSLog("------ Estimate gas used ------")
    let etherServiceRequest = KWEtherServiceRequest(
      batch: BatchFactory().create(request),
      endpoint: self.network.endpoint
    )
    DispatchQueue.global(qos: .background).async {
      Session.send(etherServiceRequest) { result in
        DispatchQueue.main.async {
          switch result {
          case .success(let value):
            let gasLimit: BigInt = {
              var limit = BigInt(value.drop0x, radix: 16) ?? BigInt()
              // Used  120% of estimated gas for safer
              limit += (limit * 20 / 100)
              return min(limit, defaultGasLimit)
            }()
            NSLog("------ Estimate gas used: \(gasLimit.fullString(units: .wei)) ------")
            completion(.success(gasLimit))
          case .failure(let error):
            NSLog("------ Estimate gas used failed: \(error.localizedDescription) ------")
            completion(.failure(AnyError(error)))
          }
        }
      }
    }
  }

  // MARK: Sign transaction
  private func signTransactionData(from transaction: KWTransaction, isPay: Bool, nonce: Int, data: Data, completion: @escaping (Result<Data, AnyError>) -> Void) {
    let to: Address? = {
      if isPay { return self.payAddress } // pay transaction
      if transaction.from != transaction.to {
        // swap
        return self.networkAddress
      }
      return Address(string: transaction.from.isETH ? transaction.destWallet : transaction.to.address)
    }()
    let gasLimit: BigInt = {
      if let gasLimit = transaction.gasLimit { return gasLimit }
      if transaction.to.isDGX || transaction.from.isDGX { return KWGasConfiguration.digixGasLimitDefault }
      if transaction.to.isETH || transaction.from.isETH { return KWGasConfiguration.exchangeETHTokenGasLimitDefault }
      return KWGasConfiguration.exchangeTokensGasLimitDefault
    }()
    let signTransaction: KWDraftTransaction = KWDraftTransaction(
      value: transaction.from.isETH ? transaction.amountFrom : BigInt(0),
      account: transaction.account!,
      to: to,
      nonce: nonce,
      data: data,
      gasPrice: transaction.gasPrice ?? KWGasConfiguration.gasPriceFast,
      gasLimit: gasLimit,
      chainID: transaction.chainID
    )
    self.signTransactionData(from: signTransaction, completion: completion)
  }

  private func signTransactionData(from signTransaction: KWDraftTransaction, completion: @escaping (Result<Data, AnyError>) -> Void) {
    let signResult = self.keystore.signTransaction(transaction: signTransaction)
    switch signResult {
    case .success(let data):
      completion(.success(data))
    case .failure(let error):
      completion(.failure(AnyError(error)))
    }
  }

  // MARK: KWWeb3Swift Encode/Decode data
  private func getExchangeTransactionDecode(_ data: String, completion: @escaping (Result<JSONDictionary, AnyError>) -> Void) {
    let request = KWExchangeEventDataDecode(data: data)
    self.web3Swift.request(request: request) { result in
      switch result {
      case .success(let json):
        completion(.success(json))
      case .failure(let error):
        if let err = error.error as? JSErrorDomain {
          if case .invalidReturnType(let object) = err, let json = object as? JSONDictionary {
            completion(.success(json))
            return
          }
        }
        completion(.failure(AnyError(error)))
      }
    }
  }

  private func requestDataForTokenTransfer(_ transaction: KWTransaction, completion: @escaping (Result<Data, AnyError>) -> Void) {
    if transaction.from.isETH && transaction.to.isETH {
      completion(.success(Data()))
      return
    }
    let request = KWTokenTransferEncode(
      amount: transaction.amountFrom.description,
      address: transaction.destWallet
    )
    self.web3Swift.request(request: request) { (result) in
      switch result {
      case .success(let res):
        let data = Data(hex: res.drop0x)
        completion(.success(data))
      case .failure(let error):
        completion(.failure(AnyError(error)))
      }
    }
  }

  public func requestDataForTokenExchange(_ exchange: KWTransaction, completion: @escaping (Result<Data, AnyError>) -> Void) {
    let address = exchange.account?.address.description ?? exchange.destWallet
    let encodeRequest = KWExchangeRequestEncode(
      exchange: exchange,
      address: address
    )
    self.web3Swift.request(request: encodeRequest) { result in
      switch result {
      case .success(let res):
        let data = Data(hex: res.drop0x)
        completion(.success(data))
      case .failure(let error):
        completion(.failure(AnyError(error)))
      }
    }
  }

  public func requestDataForPay(_ pay: KWTransaction, completion: @escaping (Result<Data, AnyError>) -> Void) {
    let networkProxy = self.networkAddress.description
    let encodeRequest = KWPayRequestEncode(pay: pay, kyberNetworkProxy: networkProxy)
    self.web3Swift.request(request: encodeRequest) { result in
      switch result {
      case .success(let res):
        let data = Data(hex: res.drop0x)
        completion(.success(data))
      case .failure(let error):
        completion(.failure(AnyError(error)))
      }
    }
  }
}
