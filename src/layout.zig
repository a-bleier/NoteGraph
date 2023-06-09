//will contain layout algorithms like Kamada/Kawai or Fruchterman/Reingold

const std = @import("std");
const Allocator = std.mem.Allocator;
const math = std.math;

const graph_lib = @import("graph.zig");
const Graph = graph_lib.Graph;

pub const LayoutMethod = enum {
    Kamada,
    Fruchterman,
};

const K: f32 = 0.1; // force factor
const C: f32 = 0.9;           // Coupling factor
const EPSILON: f32 = 0.000001;

//TODO remove width and height from function interface because width and height are now in the graph
pub fn layout(graph: *Graph, method: LayoutMethod, width: i32, height: i32) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();

    const result = switch (method) {
        .Kamada => kamada(graph),
        .Fruchterman => try generateFruchtermanLayout(graph, width, height, &allocator),
    };
    _ = try result;
}

fn kamada(graph: *Graph) !void {
    _ = graph;
}

fn generateFruchtermanLayout(graph: *Graph, width: i32, height: i32, allocator: *Allocator) !void {
    var initial_temperature: f32 = math.sqrt(@intToFloat(f32, width*height) / @intToFloat(f32, graph.nodes.keys().len));
    var temperature = initial_temperature;
    
    var i: usize = 0;
    while (i < 20) {
        defer i += 1;
        try fruchtermanLayout(graph, width, height, temperature, allocator);
        temperature *= C;   // Reduce the temperature with each iteration
    }
}

fn fruchtermanLayout(graph: *Graph, width: i32, height: i32, temperature: f32, allocator: *Allocator) !void {

    var area = width * height;
    var num_vertices = graph.nodes.keys().len;
    var k = K * math.sqrt(@intToFloat(f32, area) / @intToFloat(f32, num_vertices));
    var nodes = graph.nodes.values();

    var displacement = try allocator.alloc(graph_lib.Point, num_vertices);
    for(displacement) |*point| {
        point.*.x = 0.0;
        point.*.y = 0.0;
    }

    var i: usize = 0;
    var j: usize = 0;

    // repulsive forces
    while (i < num_vertices) {
        defer i += 1;
        while (j < num_vertices) {
            defer j += 1;
            if(i != j){
                var dx = nodes[i].position.x - nodes[j].position.x;
                var dy = nodes[i].position.y - nodes[j].position.y;
                var d = @max(EPSILON, math.sqrt(dx * dx + dy * dy));

                var fx: f32 = (k*k) / d * dx / d;
                var fy: f32 = (k*k) / d * dy / d;

                displacement[i].x += fx;
                displacement[i].y += fy;
            }

        }
    }

    //attracting forces
    for(graph.edges.keys()) |*edge| {
        var u = graph.nodes.getIndex(edge.u) orelse unreachable; 
        var v = graph.nodes.getIndex(edge.v) orelse unreachable; 

        var dx = nodes[u].position.x - nodes[v].position.x;
        var dy = nodes[u].position.y - nodes[v].position.y;
        var d = @max(EPSILON, math.sqrt(dx * dx + dy * dy));

        var fx = (d*d) / k * dx / d;
        var fy = (d*d) / k * dy / d;

        // FIXME find the ID instead of index into the field
        displacement[u].x -= fx;
        displacement[u].y -= fy;
        displacement[v].x += fx;
        displacement[v].y += fy;
    }

    //place the vertices
    i=0;
    while(i < num_vertices){
        defer i+=1;
        var disp_norm: f32 = math.sqrt(displacement[i].x * displacement[i].x + displacement[i].y * displacement[i].y);
        var xratio: f32 = @min(@fabs(displacement[i].x), temperature);
        var yratio: f32 = @min(@fabs(displacement[i].y), temperature);
        
        graph.nodes.values()[i].position.x += displacement[i].x / disp_norm * xratio;
        graph.nodes.values()[i].position.y += displacement[i].y / disp_norm * yratio;

        // Limit the positions within the canvas boundaries
        graph.nodes.values()[i].position.x = @max(0.0, @min(graph.nodes.values()[i].position.x, @intToFloat(f32, width)));
        graph.nodes.values()[i].position.y = @max(0.0, @min(graph.nodes.values()[i].position.y, @intToFloat(f32, height)));
    }

    allocator.free(displacement);
}
