# Roblox_Blender_Repo



# Move weight painted groups to rigify mesh with this script: 


---

### Markdown for Your Weight Transfer Script
Here’s how to format the script you received for transferring weights from metarig vertex groups to the generated rig’s **DEF-** bones in a Markdown file:

```markdown
# Blender Rigify Weight Transfer Script

This script transfers weights from metarig vertex groups (e.g., `thigh.L`) to the generated rig’s vertex groups (e.g., `DEF-thigh.L`) by renaming or copying weights.

```python
import bpy
obj = bpy.context.active_object  # Select your mesh first
for vg in obj.vertex_groups:
    if not vg.name.startswith("DEF-"):
        new_name = "DEF-" + vg.name
        obj.vertex_groups.new(name=new_name)
        # Copy weights to new group
        for vert in obj.data.vertices:
            try:
                weight = vg.weight(vert.index)
                obj.vertex_groups[new_name].add([vert.index], weight, 'REPLACE')
            except:
                pass
        obj.vertex_groups.remove(vg)  # Remove old group