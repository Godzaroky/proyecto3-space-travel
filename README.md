# Sistema Solar — Software Renderer

Simulación de un sistema solar renderizada con un **software renderer** escrito en Zig. Raylib se usa únicamente para abrir la ventana, presentar el framebuffer, recibir input y usar sus tipos y funciones de vectores. Todo el pipeline de renderizado (transformaciones, rasterización, z-buffer, texturas, iluminación y shaders) está implementado a mano, pixel por pixel.

**Autor:** Diego Gonzalez — 24170
**Universidad del Valle de Guatemala**

## Video

[Ver video del recorrido](PENDIENTE)

## Requisitos

- [Zig](https://ziglang.org/) 0.16.0
- [raylib-zig](https://github.com/raylib-zig/raylib-zig) (se descarga automáticamente con `zig build`)

## Cómo compilar y ejecutar

```bash
zig build run -Doptimize=ReleaseFast
```

Se recomienda compilar siempre en `ReleaseFast`, porque en modo Debug el renderer es considerablemente más lento.

## Controles

| Tecla | Acción |
|---|---|
| Mouse | Rotar cámara (yaw / pitch) |
| W / A / S / D | Mover cámara |
| Espacio / Ctrl | Subir / bajar |
| Shift | Moverse más rápido |
| Tab | Liberar / capturar el mouse |
| P | Pausar / reanudar las órbitas |
| ↑ / ↓ | Acelerar / desacelerar el tiempo |
| 1 – 9 | Viajar rápido a un cuerpo celeste |
| Esc | Salir |

## Funcionalidades

- [x] Framebuffer propio y presentación por pixel
- [x] Pipeline de rasterización con z-buffer
- [x] Back-face culling
- [x] Cámara con movimiento 3D
- [x] Sol y planetas orbitando
- [x] Lunas
- [x] Texturas por cuerpo celeste
- [x] Iluminación desde el sol
- [x] Shaders únicos por cuerpo celeste
- [ ] Skybox de estrellas
- [ ] LOD
- [ ] Nave que sigue a la cámara (modelada en Blender, con caras no triangulares)
- [ ] Colisiones con los cuerpos del sistema
- [ ] Fast travel con animación

## Shaders por cuerpo celeste

| Cuerpo | Shader | Qué lo hace especial |
|---|---|---|
| Sol | `sun` | Superficie animada con ruido fractal y pulso de brillo |
| Mercurio | `mercury` | Cel shading en 4 niveles con contorno oscuro |
| Tierra | `earth` | Transición día/noche con luces de ciudades y nubes procedurales animadas |
| Luna | `moonVertex` + `moon` | El vertex shader deforma la geometría con ruido (relieve) |
| Marte | `mars` | Tormentas de polvo animadas y brillo atmosférico en el borde |
| Júpiter | `jupiter` | Bandas que fluyen con rotación diferencial y turbulencia |
| Saturno | `saturnRing` | Anillos transparentes procedurales con división de Cassini |

## Estructura del proyecto

```
.
├── build.zig
├── build.zig.zon
├── src/
│   └── main.zig
├── assets/
│   ├── textures/
│   └── models/
└── README.md
```

## Créditos y atribuciones

- Código generado por LLMs o tomado de internet está marcado con un comentario en el archivo correspondiente.
- Texturas de planetas: [Solar System Scope](https://www.solarsystemscope.com/textures/), licencia [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- Modelo de la nave: modelado por el autor en Blender (`assets/models/ship.blend`).
