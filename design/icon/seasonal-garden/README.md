# 一隅 · 时节花景

采用自然单色剪影，保留「窗外有花斜着生长过来」的圆窗意境。

最终构图由两层组成：应用独立绘制圆窗与天气；透明植物从左下窗外斜入，枝叶在交叉处盖住窗沿，花朵偏右上，左上留白。植物不被圆形裁切。颜色取自当前皮肤。

- `source/`：内置 image_gen 生成的透明植物源图，不包含窗框。
- `paths/`：清理零散噪点后的真实 SVG 曲线路径，128×128 坐标。`*-menu.svg` 去除叶脉等封闭小孔，供 18pt 菜单栏使用。
- `composition-generation.json`：最终八种花的生成来源、项目内源图路径与 SHA-256；提示词见下项。
- `composition-prompts.json`：实际使用的完整公共提示词与八种花的细化要求。
- `prepare.py`：从生成图的 alpha 轮廓提取 SVG。使用固定版本 vtracer 0.6.15，不改动源图。
- `../../../scripts/compile-garden-artwork.py`：将路径编译为应用内不可变 CGPath，不在运行时加载位图或解析 SVG。

重新生成路径后执行 `python3 scripts/compile-garden-artwork.py`，再通过 `./scripts/ui-tour.sh --garden` 查看原生 88pt 放大图、52pt 小圆标与 18pt 菜单栏在六款皮肤中的效果。图库的天气为模拟条件；真实用户天气与数据不参与测试。

候选稿、修订前备份、原生测试截图与验收日志只保留在本地，不进入版本库；当前 SVG、源图和编译后的 Swift 路径随代码提交。应用构建不需要 Python 或图像生成服务。
