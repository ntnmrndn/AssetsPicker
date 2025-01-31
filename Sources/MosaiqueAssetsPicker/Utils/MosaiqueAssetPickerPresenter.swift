//
//  AssetPickerPresenter.swift
//  MosaiqueAssetsPicker
//
//  Created by Antoine Marandon on 27/08/2020.
//  Copyright © 2020 eureka, Inc. All rights reserved.
//

import Foundation
import Photos
import PhotosUI

/// Use this class to present the default `PHPickerViewController` instead of `MosaiqueAssetPicker` if available.
public final class MosaiqueAssetPickerPresenter: PHPickerViewControllerDelegate {
    private weak var delegate: MosaiqueAssetPickerDelegate?
    private let configuration: MosaiqueAssetPickerConfiguration

    public static func controller(delegate: MosaiqueAssetPickerDelegate, configuration: MosaiqueAssetPickerConfiguration = .init()) -> UIViewController {
        Self(delegate: delegate, configuration: configuration).controller()
    }

    private init(delegate: MosaiqueAssetPickerDelegate, configuration: MosaiqueAssetPickerConfiguration) {
        self.delegate = delegate
        self.configuration = configuration
    }

    private func controller() -> UIViewController {
        let controller: UIViewController = {
            if #available(iOS 14, *) {
                let controller = PHPickerViewController(configuration: configuration.assetPickerConfiguration)
                controller.delegate = self
                return controller
            } else {
                let controller = MosaiqueAssetPickerViewController()
                controller.configuration = configuration
                controller.pickerDelegate = delegate
                return controller
            }
        }()
        objc_setAssociatedObject(controller, Unmanaged.passUnretained(self).toOpaque(), self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return controller
    }

    @available(iOS 14, *)
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let assetsDownloads: [AssetFuture] = results.map { .init(pickerResult: $0) }
        delegate?.photoPicker(picker, didPickAssets: assetsDownloads)

        let dispatchGroup = DispatchGroup()
        var images: [UIImage] = []
        for result in results {
            dispatchGroup.enter()
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                    if let image = image as? UIImage {
                        DispatchQueue.main.async {
                            images.append(image)
                            dispatchGroup.leave()
                        }
                    } else {
                        dispatchGroup.leave()
                    }
                }
            } else {
                dispatchGroup.leave()
            }
        }
        dispatchGroup.notify(queue: DispatchQueue.main) { [weak self] in
            if images.isEmpty {
                self?.delegate?.photoPickerDidCancel(picker)
            } else {
                self?.delegate?.photoPicker(picker, didPickImages: images)
            }
        }
   }
}
