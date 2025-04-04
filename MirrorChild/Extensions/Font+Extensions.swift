//
//  Font+Extensions.swift
//  MirrorChild
//
//  Created by Zhang Haobo on 2023/5/15.
//

import SwiftUI

extension Font {
    // MARK: - PingFang SC 字体
    
    /// 创建苹方字体 - 细体
    static func pingFangLight(size: CGFloat) -> Font {
        return .custom("PingFangSC-Light", size: size)
    }
    
    /// 创建苹方字体 - 常规
    static func pingFangRegular(size: CGFloat) -> Font {
        return .custom("PingFangSC-Regular", size: size)
    }
    
    /// 创建苹方字体 - 中等
    static func pingFangMedium(size: CGFloat) -> Font {
        return .custom("PingFangSC-Medium", size: size)
    }
    
    /// 创建苹方字体 - 粗体
    static func pingFangSemibold(size: CGFloat) -> Font {
        return .custom("PingFangSC-Semibold", size: size)
    }
    
    // MARK: - SF Pro 字体
    
    /// 创建SF Pro字体 - 细体
    static func sfProLight(size: CGFloat) -> Font {
        return .custom("SFProText-Light", size: size)
    }
    
    /// 创建SF Pro字体 - 常规
    static func sfProRegular(size: CGFloat) -> Font {
        return .custom("SFProText-Regular", size: size)
    }
    
    /// 创建SF Pro字体 - 中等
    static func sfProMedium(size: CGFloat) -> Font {
        return .custom("SFProText-Medium", size: size)
    }
    
    /// 创建SF Pro字体 - 粗体
    static func sfProSemibold(size: CGFloat) -> Font {
        return .custom("SFProText-Semibold", size: size)
    }
    
    /// 创建SF Pro字体 - 黑体
    static func sfProBold(size: CGFloat) -> Font {
        return .custom("SFProText-Bold", size: size)
    }
    
    // MARK: - 通用智能字体选择
    
    /// 根据当前系统语言自动选择合适的字体
    /// 中文环境下使用苹方，其他环境使用SF Pro
    static func appFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let isChinese = Locale.current.language.languageCode?.identifier == "zh"
        
        switch weight {
        case .ultraLight, .thin, .light:
            return isChinese ? .pingFangLight(size: size) : .sfProLight(size: size)
        case .regular:
            return isChinese ? .pingFangRegular(size: size) : .sfProRegular(size: size)
        case .medium:
            return isChinese ? .pingFangMedium(size: size) : .sfProMedium(size: size)
        case .semibold:
            return isChinese ? .pingFangSemibold(size: size) : .sfProSemibold(size: size)
        case .bold, .heavy, .black:
            return isChinese ? .pingFangSemibold(size: size) : .sfProBold(size: size)
        default:
            return isChinese ? .pingFangRegular(size: size) : .sfProRegular(size: size)
        }
    }
} 