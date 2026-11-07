#include "PacketPlayerEquipment.hpp"

#include <components/openmw-mp/NetworkMessages.hpp>

using namespace mwmp;

PacketPlayerEquipment::PacketPlayerEquipment(RakNet::RakPeerInterface *peer) : PlayerPacket(peer)
{
    packetID = ID_PLAYER_EQUIPMENT;
}

void PacketPlayerEquipment::Packet(RakNet::BitStream *newBitstream, bool send)
{
    PlayerPacket::Packet(newBitstream, send);

    RW(player->exchangeFullInfo, send);

    if (player->exchangeFullInfo)
    {
        for (auto &&equipmentItem : player->equipmentItems)
        {
            ExchangeItemInformation(equipmentItem, send);
        }
    }
    else
    {
        uint32_t count = 0;
        if (send)
            count = static_cast<uint32_t>(player->equipmentIndexChanges.size());

        RW(count, send);

        if (count > maxEquipmentSlots)
        {
            packetValid = false;
            return;
        }

        if (!send)
        {
            player->equipmentIndexChanges.clear();
            player->equipmentIndexChanges.resize(count);
        }

        for (auto &&equipmentIndex : player->equipmentIndexChanges)
        {
            RW(equipmentIndex, send);

            if (equipmentIndex < 0 || equipmentIndex >= maxEquipmentSlots)
            {
                packetValid = false;
                return;
            }

            ExchangeItemInformation(player->equipmentItems[equipmentIndex], send);
        }
    }
}

void PacketPlayerEquipment::ExchangeItemInformation(Item &item, bool send)
{
    RW(item.refId, send, true);
    RW(item.count, send);
    RW(item.charge, send);
    RW(item.enchantmentCharge, send);
}

