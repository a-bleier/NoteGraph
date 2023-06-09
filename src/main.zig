const std = @import("std");
const proc = std.process;
const mem = std.mem;

const config = @import("config.zig");
const graph_lib = @import("graph.zig");
const utils = @import("utils.zig");
const rendering_lib = @import("renderer.zig");
const layout = @import("layout.zig");
const Graph = graph_lib.Graph;
const Renderer = rendering_lib.Renderer;

const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const WINDOW_WIDTH: i32 = 1500;
const WINDOW_HEIGHT: i32 = 1000;

const FPS: u32 = 30;

const BACKGROUND_COLOR: u32 = 0xFF181818; // abgr
const ORANGE_COLOR: u32 = 0xFF5396EE; // abgr

var quit = false;
const stdout = std.io.getStdOut().writer();
const debug = std.debug;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    var ngConf: config.NGConfig = try getConfig(arena.allocator());
    defer ngConf.deinit();
    
    var file_types = std.ArrayList([]const u8).init(arena.allocator());
    defer file_types.deinit();

    try file_types.append("md");
    try file_types.append("txt");

    var files = try utils.traverseRoot(gpa.allocator(), ngConf.root, &file_types);

    var graph: Graph = try Graph.init(gpa.allocator(), files, @intToFloat(f32, WINDOW_WIDTH), @intToFloat(f32, WINDOW_HEIGHT));
    defer graph.deinit();

    try layout.layout(&graph, layout.LayoutMethod.Fruchterman, WINDOW_WIDTH, WINDOW_HEIGHT);

    var renderer = try Renderer.init(WINDOW_WIDTH, WINDOW_HEIGHT, ngConf.font_size, arena.allocator());
    defer renderer.deinit();

    // try startWindow();

   while (!quit){
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                c.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }
        
        try renderer.updateRenderData(&graph);
        try renderer.render(&graph);

        _ = c.SDL_Delay(1000/30);     
    }
}

pub fn getConfig(allocator: mem.Allocator) !config.NGConfig {
    
    var args = try proc.ArgIterator.initWithAllocator(allocator);
    defer args.deinit();

    var map = std.StringHashMap([]const u8).init(
        allocator
    );
    defer map.deinit();


    var counter: u32 = 0;
    while(args.next()) |arg| {
        if(counter == 0){
            counter += 1;
            continue;
        }
        
        if(std.mem.eql(u8, arg, "--root")) {
            var root = args.next() orelse break;

            try map.put("root", root);
            debug.print("{s}\n", .{root});

        } else if(std.mem.eql(u8, arg, "--config")) {
            var config_path: []const u8 = args.next() orelse break;

            try map.put("config", config_path);
            debug.print("{s}\n", .{config_path});

        } else if(std.mem.eql(u8, arg, "--fontsize")) {
            var fontsize : []const u8 = args.next() orelse break;

            try map.put("fontsize", fontsize);

        } else {
            debug.print("{s}\n", .{arg});
        }

        counter += 1;

    } 
    var conf: config.NGConfig = try config.NGConfig.init(allocator, map);

    return conf;
}

