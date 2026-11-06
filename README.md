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
| 1 – 9 | Viajar rápido a un cuerpo celeste |
| Esc | Salir |

## Funcionalidades

- [ ] Framebuffer propio y presentación por pixel
- [ ] Pipeline de rasterización con z-buffer
- [ ] Back-face culling
- [ ] Cámara con movimiento 3D
- [ ] Sol y planetas orbitando
- [ ] Lunas
- [ ] Texturas por cuerpo celeste
- [ ] Iluminación desde el sol
- [ ] Shaders únicos por cuerpo celeste
- [ ] Skybox de estrellas
- [ ] LOD
- [ ] Nave que sigue a la cámara (modelada en Blender, con caras no triangulares)
- [ ] Colisiones con los cuerpos del sistema
- [ ] Fast travel con animación

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
- Texturas: *(pendiente: listar fuentes y licencias)*
- Modelo de la nave: modelado por el autor en Blender (`assets/models/ship.blend`).
