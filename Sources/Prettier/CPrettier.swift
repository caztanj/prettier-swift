import Foundation
import Darwin

public final class PrettierOptionsHolder: @unchecked Sendable {
    public var options = PrintOptions()
}

@_cdecl("prettier_options_create")
public func prettier_options_create() -> UnsafeMutableRawPointer {
    let holder = PrettierOptionsHolder()
    return Unmanaged.passRetained(holder).toOpaque()
}

@_cdecl("prettier_options_destroy")
public func prettier_options_destroy(_ ptr: UnsafeMutableRawPointer?) {
    guard let ptr else { return }
    Unmanaged<PrettierOptionsHolder>.fromOpaque(ptr).release()
}

@_cdecl("prettier_options_set_print_width")
public func prettier_options_set_print_width(_ ptr: UnsafeMutableRawPointer?, _ width: Int32) {
    guard let ptr else { return }
    let holder = Unmanaged<PrettierOptionsHolder>.fromOpaque(ptr).takeUnretainedValue()
    holder.options.printWidth = Int(width)
}

@_cdecl("prettier_options_set_tab_width")
public func prettier_options_set_tab_width(_ ptr: UnsafeMutableRawPointer?, _ width: Int32) {
    guard let ptr else { return }
    let holder = Unmanaged<PrettierOptionsHolder>.fromOpaque(ptr).takeUnretainedValue()
    holder.options.tabWidth = Int(width)
}

@_cdecl("prettier_options_set_use_tabs")
public func prettier_options_set_use_tabs(_ ptr: UnsafeMutableRawPointer?, _ useTabs: Bool) {
    guard let ptr else { return }
    let holder = Unmanaged<PrettierOptionsHolder>.fromOpaque(ptr).takeUnretainedValue()
    holder.options.useTabs = useTabs
}

@_cdecl("prettier_options_set_semi")
public func prettier_options_set_semi(_ ptr: UnsafeMutableRawPointer?, _ semi: Bool) {
    guard let ptr else { return }
    let holder = Unmanaged<PrettierOptionsHolder>.fromOpaque(ptr).takeUnretainedValue()
    holder.options.semi = semi
}

@_cdecl("prettier_options_set_single_quote")
public func prettier_options_set_single_quote(_ ptr: UnsafeMutableRawPointer?, _ singleQuote: Bool) {
    guard let ptr else { return }
    let holder = Unmanaged<PrettierOptionsHolder>.fromOpaque(ptr).takeUnretainedValue()
    holder.options.singleQuote = singleQuote
}

@_cdecl("prettier_options_set_bracket_spacing")
public func prettier_options_set_bracket_spacing(_ ptr: UnsafeMutableRawPointer?, _ bracketSpacing: Bool) {
    guard let ptr else { return }
    let holder = Unmanaged<PrettierOptionsHolder>.fromOpaque(ptr).takeUnretainedValue()
    holder.options.bracketSpacing = bracketSpacing
}

@_cdecl("prettier_free_string")
public func prettier_free_string(_ ptr: UnsafeMutablePointer<CChar>?) {
    guard let ptr else { return }
    free(ptr)
}

@_cdecl("prettier_format")
public func prettier_format(
    _ source: UnsafePointer<CChar>?,
    _ filepath: UnsafePointer<CChar>?,
    _ parser: UnsafePointer<CChar>?,
    _ options: UnsafeRawPointer?,
    _ error_out: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> UnsafeMutablePointer<CChar>? {
    guard let source else {
        if let error_out {
            error_out.pointee = strdup("source cannot be null")
        }
        return nil
    }

    let sourceString = String(cString: source)
    let filepathString = filepath.map { String(cString: $0) }
    let parserString = parser.map { String(cString: $0) }

    var printOptions = PrintOptions()
    if let options {
        let holder = Unmanaged<PrettierOptionsHolder>.fromOpaque(options).takeUnretainedValue()
        printOptions = holder.options
    }

    do {
        let formatted = try Prettier.format(
            sourceString,
            filepath: filepathString,
            parser: parserString,
            options: printOptions
        )
        return strdup(formatted)
    } catch {
        if let error_out {
            error_out.pointee = strdup("\(error)")
        }
        return nil
    }
}

@_cdecl("prettier_format_simple")
public func prettier_format_simple(
    _ source: UnsafePointer<CChar>?,
    _ filepath: UnsafePointer<CChar>?,
    _ parser: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>? {
    prettier_format(source, filepath, parser, nil, nil)
}

@_cdecl("prettier_check")
public func prettier_check(
    _ source: UnsafePointer<CChar>?,
    _ filepath: UnsafePointer<CChar>?,
    _ parser: UnsafePointer<CChar>?,
    _ options: UnsafeRawPointer?,
    _ error_out: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    guard let source else {
        if let error_out {
            error_out.pointee = strdup("source cannot be null")
        }
        return -1
    }

    let sourceString = String(cString: source)
    let filepathString = filepath.map { String(cString: $0) }
    let parserString = parser.map { String(cString: $0) }

    var printOptions = PrintOptions()
    if let options {
        let holder = Unmanaged<PrettierOptionsHolder>.fromOpaque(options).takeUnretainedValue()
        printOptions = holder.options
    }

    do {
        let isFormatted = try Prettier.check(
            sourceString,
            filepath: filepathString,
            parser: parserString,
            options: printOptions
        )
        return isFormatted ? 1 : 0
    } catch {
        if let error_out {
            error_out.pointee = strdup("\(error)")
        }
        return -1
    }
}
