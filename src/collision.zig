const rl = @import("raylib");
const std = @import("std");
const SolarSystem = @import("solar_system.zig").SolarSystem;
const Body = @import("solar_system.zig").Body;
const Ship = @import("ship.zig").Ship;
const Camera = @import("camera.zig").Camera;

const Vector3 = rl.Vector3;

// distancia mínima entre la cámara y una superficie
const camera_margin: f32 = 0.5;
// grosor de los anillos para colisiones
const ring_thickness: f32 = 0.3;
const ring_inner: f32 = 1.3;
const ring_outer: f32 = 2.4;
const passes = 3;

fn collisionRadius(body: Body) f32 {
    // la luna tiene relieve que sobresale de su radio
    const relief: f32 = if (body.vertex != null) 1.2 else 1.0;
    return body.radius * relief;
}

// empuje necesario para sacar un punto de una esfera
fn sphereCorrection(point: Vector3, center: Vector3, radius: f32) ?Vector3 {
    const d = point.subtract(center);
    const dist = d.length();
    if (dist >= radius) return null;
    const dir = if (dist > 0.0001) d.scale(1 / dist) else Vector3{ .x = 0, .y = 1, .z = 0 };
    return dir.scale(radius - dist);
}

// empuje necesario para sacar un punto del anillo
fn ringCorrection(point: Vector3, body: Body, extra: f32) ?Vector3 {
    const normal = Vector3{ .x = -@sin(body.axial_tilt), .y = @cos(body.axial_tilt), .z = 0 };
    const rel = point.subtract(body.position);
    const h = rel.dotProduct(normal);
    const radial = rel.subtract(normal.scale(h)).length();

    const half = ring_thickness * 0.5 + extra;
    const inner = body.radius * ring_inner - extra;
    const outer = body.radius * ring_outer + extra;
    if (@abs(h) >= half or radial < inner or radial > outer) return null;

    const side: f32 = if (h >= 0) 1 else -1;
    return normal.scale(side * (half - @abs(h)));
}

// evita que la cámara o la nave atraviesen los cuerpos; devuelve si hubo colisión
pub fn resolve(camera: *Camera, system: *const SolarSystem, ship: *const Ship) bool {
    var collided = false;

    for (0..passes) |_| {
        var moved = false;

        for (system.bodies) |body| {
            const r = collisionRadius(body);

            if (sphereCorrection(camera.position, body.position, r + camera_margin)) |push| {
                camera.position = camera.position.add(push);
                moved = true;
            }

            // la nave se mueve junto con la cámara
            const ship_pos = Ship.position(camera.*);
            if (sphereCorrection(ship_pos, body.position, r + ship.radius)) |push| {
                camera.position = camera.position.add(push);
                moved = true;
            }

            if (body.has_ring) {
                if (ringCorrection(camera.position, body, camera_margin)) |push| {
                    camera.position = camera.position.add(push);
                    moved = true;
                }
                if (ringCorrection(Ship.position(camera.*), body, ship.radius)) |push| {
                    camera.position = camera.position.add(push);
                    moved = true;
                }
            }
        }

        if (!moved) break;
        collided = true;
    }

    return collided;
}
