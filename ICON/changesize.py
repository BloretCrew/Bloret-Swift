from PIL import Image
import os

def resize_app_icon(input_path, output_path, size=(1024, 1024)):
    try:
        with Image.open(input_path) as img:
            # 转换为带有 Alpha 通道的 RGBA 模式，确保兼容性
            img = img.convert("RGBA")
            
            # 保持比例缩放并裁剪中心，确保结果正好是 1024x1024
            # 如果原图比例不对，这比直接缩放效果更好
            from PIL import ImageOps
            result = ImageOps.fit(img, size, Image.Resampling.LANCZOS)
            
            # 保存图片
            result.save(output_path, "PNG")
            print(f"✅ 处理成功: {output_path}")
            
    except Exception as e:
        print(f"❌ 处理失败: {e}")

# --- 使用示例 ---
# 请将下面的文件名替换为你实际的文件名
input_file = "Bloret-watchOS-Default-1088x1088@1x.png"
output_file = "Bloret-watchOS-Default-1024x1024@1x.png"

resize_app_icon(input_file, output_file)