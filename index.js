const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const axios = require('axios');
const { v4: uuidv4 } = require('uuid');

const XRAY_VERSION = '1.8.10'; // 可以根据需要更新 Xray 版本
const XRAY_DOWNLOAD_URL = `https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip`;
const XRAY_DIR = path.join(__dirname, 'xray');
const XRAY_BIN = path.join(XRAY_DIR, 'xray');
const XRAY_CONFIG_PATH = path.join(__dirname, 'config.json');

async function main() {
    console.log('🚀 正在启动 lunes.host Xray 节点部署...');

    // 1. 获取端口和 UUID
    const PORT = process.env.SERVER_PORT || 3256; // 使用面板分配的端口，如果未设置则默认 3256
    const UUID = process.env.UUID || uuidv4();
    const DOMAIN = process.env.DOMAIN || 'node70.lunes.host'; // 使用用户提供的域名
    const WS_PATH = process.env.WS_PATH || '/lunes';

    console.log(`使用端口: ${PORT}, UUID: ${UUID}, 域名: ${DOMAIN}, WS路径: ${WS_PATH}`);

    // 2. 下载并解压 Xray 核心
    if (!fs.existsSync(XRAY_BIN)) {
        console.log('📥 正在下载 Xray 核心...');
        try {
            const response = await axios({
                method: 'get',
                url: XRAY_DOWNLOAD_URL,
                responseType: 'arraybuffer'
            });
            const zipPath = path.join(__dirname, 'xray.zip');
            fs.writeFileSync(zipPath, response.data);

            fs.mkdirSync(XRAY_DIR, { recursive: true });
            execSync(`unzip -o ${zipPath} -d ${XRAY_DIR}`);
            fs.unlinkSync(zipPath);
            fs.chmodSync(XRAY_BIN, '755');
            console.log('✅ Xray 核心下载并解压完成。');
        } catch (error) {
            console.error('❌ Xray 核心下载或解压失败:', error.message);
            process.exit(1);
        }
    } else {
        console.log('✅ Xray 核心已存在，跳过下载。');
    }

    // 3. 生成 Xray 配置文件
    console.log('📝 正在生成 Xray 配置文件...');
    const config = {
        "log": {
            "loglevel": "warning"
        },
        "inbounds": [
            {
                "port": parseInt(PORT),
                "protocol": "vless",
                "settings": {
                    "clients": [
                        {
                            "id": UUID,
                            "level": 0
                        }
                    ],
                    "decryption": "none"
                },
                "streamSettings": {
                    "network": "ws",
                    "wsSettings": {
                        "path": WS_PATH
                    }
                }
            }
        ],
        "outbounds": [
            {
                "protocol": "freedom"
            }
        ]
    };
    fs.writeFileSync(XRAY_CONFIG_PATH, JSON.stringify(config, null, 2));
    console.log('✅ Xray 配置文件生成完成。');

    // 4. 启动 Xray 服务
    console.log('🚀 正在启动 Xray 服务...');
    const xrayProcess = execSync(`${XRAY_BIN} run -c ${XRAY_CONFIG_PATH}`, { stdio: 'inherit' });
    console.log('✅ Xray 服务已启动。');

    // 5. 输出 VLESS 链接
    const VLESS_LINK = `vless://${UUID}@${DOMAIN}:${PORT}?encryption=none&security=none&type=ws&path=${WS_PATH}#lunes_node`;
    console.log('\n========================================');
    console.log('🎉 部署成功！你的 VLESS 节点信息如下：');
    console.log(`  地址: ${DOMAIN}`);
    console.log(`  端口: ${PORT}`);
    console.log(`  UUID: ${UUID}`);
    console.log(`  路径: ${WS_PATH}`);
    console.log(`  链接: ${VLESS_LINK}`);
    console.log('========================================');
    console.log('请将此链接复制到你的 VLESS 客户端中使用。');
}

main().catch(error => {
    console.error('❌ 部署过程中发生错误:', error);
    process.exit(1);
});
