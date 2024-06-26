const std = @import("std");

const string_format = @import("string_format.zig");

const DateTime = @This();

year: u32,
month: u32,
day: u32,
hour: u32,
minute: u32,
second: u32,
millis: u32,
nanos: u32,

pub fn getNow() DateTime {
    return fromTimestamp(@intCast(std.time.nanoTimestamp()));
}

pub fn getNowString(allocator: std.mem.Allocator) []u8 {
    const dt = fromTimestamp(@intCast(std.time.nanoTimestamp()));
    return toString(dt, allocator);
}

pub fn fromTimestamp(time_stamp: u64) DateTime {
    const NANOS_PER_DAY = 86400000000000;

    const START_YEAR: u16 = 1970;
    const DAYS_IN_YEAR = 365;
    const DAYS_IN_LEAP_YEAR = 366;
    const DAYS_PER_MONTH = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    const DAYS_PER_MONTH_IN_LEAP_YEAR = [_]u8{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

    var current_year = START_YEAR;
    var days_in_year: u16 = DAYS_IN_YEAR;

    var days: u64 = @intCast(time_stamp / NANOS_PER_DAY);

    while (days > days_in_year) {
        days = days - days_in_year;
        current_year = current_year + 1;

        if (isLeapYear(current_year)) {
            days_in_year = DAYS_IN_LEAP_YEAR;
        } else {
            days_in_year = DAYS_IN_YEAR;
        }
    }

    const days_per_month: [12]u8 = switch (isLeapYear(current_year)) {
        true => DAYS_PER_MONTH_IN_LEAP_YEAR,
        false => DAYS_PER_MONTH,
    };

    var month: u8 = 1;
    while (days > days_per_month[month]) {
        days = days - days_per_month[month];
        month = month + 1;
    }

    const nanos_since_midnight: u64 = @rem(time_stamp, NANOS_PER_DAY);

    const hours: u32 = @intCast(nanos_since_midnight / 3600000000000);
    var remaining_nanos = nanos_since_midnight % 3600000000000;

    const minutes: u32 = @intCast(remaining_nanos / 60000000000);
    remaining_nanos = remaining_nanos % 60000000000;

    const seconds: u32 = @intCast(remaining_nanos / 1000000000);
    remaining_nanos = remaining_nanos % 1000000000;

    const millis: u32 = @intCast(remaining_nanos / 1000000);
    remaining_nanos = remaining_nanos % 1000000;

    return DateTime{
        .year = current_year,
        .month = month,
        .day = @intCast(days + 1),
        .hour = hours,
        .minute = minutes,
        .second = seconds,
        .millis = millis,
        .nanos = @intCast(remaining_nanos),
    };
}

fn toString(dt: DateTime, allocator: std.mem.Allocator) []u8 {
    const year_str = string_format.padString(
        allocator,
        std.fmt.allocPrint(allocator, "{d}", .{dt.year}) catch unreachable,
        4,
        "0",
    );

    const month_str = string_format.padString(
        allocator,
        std.fmt.allocPrint(allocator, "{d}", .{dt.month}) catch unreachable,
        2,
        "0",
    );

    const day_str = string_format.padString(
        allocator,
        std.fmt.allocPrint(allocator, "{d}", .{dt.day}) catch unreachable,
        2,
        "0",
    );

    const hour_str = string_format.padString(
        allocator,
        std.fmt.allocPrint(allocator, "{d}", .{dt.hour}) catch unreachable,
        2,
        "0",
    );

    const min_str = string_format.padString(
        allocator,
        std.fmt.allocPrint(allocator, "{d}", .{dt.minute}) catch unreachable,
        2,
        "0",
    );

    const sec_str = string_format.padString(
        allocator,
        std.fmt.allocPrint(allocator, "{d}", .{dt.second}) catch unreachable,
        2,
        "0",
    );

    const mil_str = string_format.padString(
        allocator,
        std.fmt.allocPrint(allocator, "{d}", .{dt.millis}) catch unreachable,
        3,
        "0",
    );

    const nano_str = string_format.padString(
        allocator,
        std.fmt.allocPrint(allocator, "{d}", .{dt.nanos}) catch unreachable,
        10,
        "0",
    );

    const date_str = std.fmt.allocPrint(allocator, "{s}/{s}/{s} {s}:{s}:{s}:{s}:{s}", .{
        day_str,
        month_str,
        year_str,
        hour_str,
        min_str,
        sec_str,
        mil_str,
        nano_str,
    }) catch unreachable;

    return date_str;
}

inline fn isLeapYear(year: u16) bool {
    if (year % 4 == 0 and ((year % 100 != 0) or (year % 400 == 0))) return true;
    return false;
}