# Agent Learnings

## WAIT-001 - Pi Easter Egg Implementation

### Patterns Used
- Hidden trigger element with minimal opacity (`rgba(74, 124, 155, 0.1)`) for discovery
- CSS custom properties (`--tx`, `--ty`, `--rot`) for dynamic animation values
- Multiple layered visual effects for stunning impact:
  - Expanding wave animations
  - Particle explosion with pi digits
  - Golden ratio spiral overlay
- Cleanup pattern: `setTimeout(() => element.remove(), duration)` to prevent DOM bloat

### Gotchas
- Easter eggs should be truly hidden - used bottom-left corner with very low opacity
- z-index layering critical: trigger (999), waves (9998), explosion (9999)
- Animation timing must be coordinated: wave delay at 300ms intervals
- Remember to remove dynamically created elements to avoid memory leaks

### Visual Effect Techniques
- Used mathematical constants (pi digits, golden ratio) for thematic consistency
- Particle distribution using radial math: `angle = (Math.PI * 2 * i) / particleCount`
- Combined multiple animation types: scale, translate, rotate, opacity for depth
- SVG for geometric shapes (spiral) with CSS animation wrapper
