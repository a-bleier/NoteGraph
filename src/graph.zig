const std = @import("std");
const Allocator = std.mem.Allocator;
const test_allocator = std.testing.allocator;
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const random = std.crypto.random;
const math = std.math;

const utils = @import("utils.zig");
const renderer = @import("renderer.zig");

pub const Node = struct {
    id: u32,
    file: []const u8,
    path: []const u8,
    edges: std.ArrayList(u32),
    file_links: std.ArrayList([]const u8), //owned externally
    hashtags: std.ArrayList([]const u8),
    created: i64, //time stamp
    position: Point,
    render_data: ?*renderer.NodeRenderData, // not owned
};

const Edge = struct {
    u: u32,
    v: u32,
};

/// x and y in [0,1) 
pub const Point = struct {
    x: f32,
    y: f32,
};

pub fn distance(p1: Point, p2: Point) f32 {
    var dx = p1.x - p2.x;
    var dy = p1.y - p2.y;
    return math.sqrt(dx * dx + dy * dy);
}

pub const Graph = struct {
    allocator: Allocator,
    nodes: std.AutoArrayHashMap(u32, Node),
    edges: std.AutoArrayHashMap(Edge, void),
    id_lookup: std.StringArrayHashMap(u32),
    window_width: f32,
    window_height: f32,

    pub fn init(allocator: Allocator, files: std.ArrayList([]const u8), window_width: f32, window_height: f32) !Graph {

        var nodes = std.AutoArrayHashMap(u32, Node).init(allocator);
        var edges = std.AutoArrayHashMap(Edge, void).init(allocator);
        var id_lookup = std.StringArrayHashMap(u32).init(allocator);

        var graph = Graph {
            .allocator=allocator,
            .nodes=nodes,
            .edges=edges,
            .id_lookup=id_lookup,
            .window_width=window_width,
            .window_height=window_height,
        };

        try graph.update(files);

        return graph;
    }

    ///Updates the graph with new file list
    pub fn update(self: *Graph, files: std.ArrayList([]const u8)) !void {
        
        for(files.items) |file| {
            if(self.id_lookup.contains(file)){
                // receive id and then a Node
                // update node
                // update edges
            
            } else {
                // create new entry in id_lookup
                var id = std.hash.CityHash32.hash(file);
                //TODO What to do when hash collision
                var file_cpy = try self.allocator.dupe(u8, file);
                try self.id_lookup.put(file_cpy, id);

                //get links
                var file_links = try utils.getLinks(self.allocator, file, files);

                //get hashtags
                var hashtags = try utils.getHashtags(self.allocator, file);

                // create new Node
                var node: Node = Node {
                    .id = id,
                    .file = std.fs.path.basename(file_cpy),
                    .path = file_cpy,
                    .edges = std.ArrayList(u32).init(self.allocator),
                    .file_links = file_links,
                    .hashtags = hashtags,
                    .created = std.time.milliTimestamp(),
                    .position = Point {.x=random.float(f32) * self.window_width, .y=random.float(f32) * self.window_height},
                    .render_data = null
                };
                // update nodes
                try self.nodes.put(id, node);
            }
        }
        try updateEdges(self);
    }

    ///Call this if a file was deleted and needs to be removed from the graph
    pub fn remove(self: *Graph, id: u32) !void {
        //TODO Implement
        _ = id;
        _ = self;
    }

    ///clears edges and computes them again
    fn updateEdges(self: *Graph) !void {
        //TODO Insert edges only once (check if a node with swapped(u,v) already exists)
        var iter = self.nodes.iterator();
        self.edges.clearAndFree();
        while(iter.next()) |entry| {
            var node: *Node = entry.value_ptr;
            for(node.file_links.items) |link| {
                var v = node.id;

                var u = self.id_lookup.get(link) orelse {
                    std.debug.print("Skipped {s}\n", .{link});
                    continue;
                };

                var edge: Edge = .{.v=v, .u=u};
                var adv_edge: Edge = .{.v=u, .u=v};

                if(!self.edges.contains(adv_edge)){
                    try self.edges.put(edge, {});
                }

            }
        }
    }

    pub fn deinit(self: *Graph) void {
        //TODO deinit all nodes
        var iter = self.id_lookup.iterator();
        while(iter.next()) |entry| {
            var file: []const u8 = entry.key_ptr.*;
            self.allocator.free(file);

            var node: Node = self.nodes.get(entry.value_ptr.*) orelse unreachable;
            var file_links = node.file_links;
            _ = file_links;

            node.file_links.deinit();
            node.edges.deinit();
            node.hashtags.deinit();
        }


        self.nodes.deinit();
        self.edges.deinit();
        self.id_lookup.deinit();
    }
};

test "Simple Graph" {
    std.debug.print("\n", .{}); // new line from Test [] line

    var file_types = std.ArrayList([]const u8).init(test_allocator);
    defer file_types.deinit();

    try file_types.append("md");
    try file_types.append("txt");

    var root = std.fs.cwd().realpathAlloc(test_allocator, "./test") catch |err| {
        try stderr.print("test is not a valid dir\n", .{});
        return err;
    };
    defer test_allocator.free(root);

    var files = try utils.traverseRoot(test_allocator, root, &file_types);

    var graph: Graph = try Graph.init(test_allocator, files);

    for(files.items) |el| {
        test_allocator.free(el);
    }
    files.deinit();

    defer graph.deinit();
}
