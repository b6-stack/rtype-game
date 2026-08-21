import os
import glob

def fix_tres_files(directory, class_name, script_path):
    files = glob.glob(os.path.join(directory, "*.tres"))
    for file in files:
        with open(file, "r") as f:
            content = f.read()
        
        # Check if already fixed
        if "script = ExtResource" in content:
            continue
            
        # Replace header
        header_old = f'[gd_resource type="{class_name}"'
        header_new = f'[gd_resource type="Resource" script_class="{class_name}" load_steps=2 format=3]'
        
        lines = content.split('\n')
        new_lines = []
        for line in lines:
            if line.startswith('[gd_resource type="'):
                new_lines.append(header_new)
                new_lines.append('')
                new_lines.append(f'[ext_resource type="Script" path="{script_path}" id="1_script"]')
            elif line.startswith('[resource]'):
                new_lines.append(line)
                new_lines.append('script = ExtResource("1_script")')
            else:
                new_lines.append(line)
                
        with open(file, "w") as f:
            f.write('\n'.join(new_lines))
        print(f"Fixed {file}")

if __name__ == "__main__":
    fix_tres_files("d:/ProgrammingRepo/rtype-game/resources/weapons", "WeaponData", "res://resources/WeaponData.gd")
    fix_tres_files("d:/ProgrammingRepo/rtype-game/resources/enemies", "EnemyData", "res://resources/EnemyData.gd")
    fix_tres_files("d:/ProgrammingRepo/rtype-game/resources/bosses", "BossData", "res://resources/BossData.gd")
