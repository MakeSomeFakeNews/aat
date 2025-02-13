#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

// 定义字节序检查宏
#define IS_LITTLE_ENDIAN (*(uint16_t *)"\x01\x00" == 0x01)

// 位置数据类型
#define TYPE_CURRENT 0x01  // 当前位置
#define TYPE_HOME    0x02  // 家的位置

// 定义数据包结构
#pragma pack(1)
typedef struct {
    uint8_t header[2];    // 帧头 0xAA 0x55
    uint8_t type;        // 位置类型
    float latitude;      // 纬度
    float longitude;     // 经度
    uint8_t checksum;    // 校验和
} LocationPacket;
#pragma pack()

// 字节序转换
float convert_float(float value) {
    if (IS_LITTLE_ENDIAN) {
        return value;
    } else {
        uint32_t temp;
        memcpy(&temp, &value, sizeof(float));
        temp = ((temp & 0xFF000000) >> 24) |
               ((temp & 0x00FF0000) >> 8) |
               ((temp & 0x0000FF00) << 8) |
               ((temp & 0x000000FF) << 24);
        float result;
        memcpy(&result, &temp, sizeof(float));
        return result;
    }
}

// 计算校验和
uint8_t calculate_checksum(const uint8_t* data, size_t length) {
    uint8_t checksum = 0;
    for (size_t i = 0; i < length; i++) {
        checksum ^= data[i];
    }
    return checksum;
}

// 解析位置数据包
bool parse_location_packet(const uint8_t* data, size_t length, float* lat, float* lon, uint8_t* type) {
    if (length != sizeof(LocationPacket)) {
        printf("错误：数据长度不正确（期望%zu字节，实际%zu字节）\n",
               sizeof(LocationPacket), length);
        return false;
    }

    const LocationPacket* packet = (const LocationPacket*)data;

    // 检查帧头
    if (packet->header[0] != 0xAA || packet->header[1] != 0x55) {
        printf("错误：帧头不正确（0x%02X 0x%02X）\n",
               packet->header[0], packet->header[1]);
        return false;
    }

    // 验证校验和
    uint8_t calculated_checksum = calculate_checksum(data, length - 1);
    if (calculated_checksum != packet->checksum) {
        printf("错误：校验和不匹配（计算值：0x%02X，接收值：0x%02X）\n",
               calculated_checksum, packet->checksum);
        return false;
    }

    if (packet->type != TYPE_CURRENT && packet->type != TYPE_HOME) {
        printf("错误：位置类型不正确（0x%02X）\n", packet->type);
        return false;
    }

    *lat = convert_float(packet->latitude);
    *lon = convert_float(packet->longitude);
    *type = packet->type;

    return true;
}

void process_received_data(const uint8_t* data, size_t length) {
    float latitude, longitude;
    uint8_t type;
    if (parse_location_packet(data, length, &latitude, &longitude, &type)) {
        printf("解析成功：\n");
        printf("类型：%s\n", type == TYPE_CURRENT ? "当前位置" : "家的位置");
        printf("纬度：%.6f\n", latitude);
        printf("经度：%.6f\n", longitude);
    } else {
        printf("数据包解析失败\n");
    }
}

// 测试
int main() {
    printf("系统字节序: %s\n", IS_LITTLE_ENDIAN ? "小端序" : "大端序");
    uint8_t test_data1[] = {
        0xAA, 0x55,                 // 帧头
        TYPE_CURRENT,              // 类型：当前位置
        0x04, 0x7E, 0x1F, 0x42,    // 纬度 (39.9042)
        0x81, 0x14, 0xE9, 0x42,    // 经度 (116.4074)
        0x00                       // 校验和
    };
    test_data1[11] = calculate_checksum(test_data1, 11);
    printf("\n测试 1 - 当前位置数据包:\n");
    process_received_data(test_data1, sizeof(test_data1));
    uint8_t test_data2[] = {
        0xAA, 0x55,                 // 帧头
        TYPE_HOME,                 // 类型：家的位置
        0x04, 0x7E, 0x1F, 0x42,    // 纬度 (39.9042)
        0x81, 0x14, 0xE9, 0x42,    // 经度 (116.4074)
        0x00                       // 校验和
    };
    test_data2[11] = calculate_checksum(test_data2, 11);
    printf("\n测试 2 - 家的位置数据包:\n");
    process_received_data(test_data2, sizeof(test_data2));

    return 0;
}