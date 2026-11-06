#ifndef OPENMW_PLAYERPACKET_HPP
#define OPENMW_PLAYERPACKET_HPP

#include <string>
#include <RakNetTypes.h>
#include <BitStream.h>
#include <PacketPriority.h>
#include <components/openmw-mp/Base/BasePlayer.hpp>

#include <components/openmw-mp/Packets/BasePacket.hpp>

namespace mwmp
{
    class PlayerPacket : public BasePacket
    {
    public:
        PlayerPacket(RakNet::RakPeerInterface *peer);

        ~PlayerPacket();

        void setPlayer(BasePlayer *newPlayer);
        BasePlayer *getPlayer();

    protected:
        BasePlayer *player;

        // Upper bound for the element counts these packets read off the wire,
        // which are otherwise passed straight to resize(). Set well above any
        // count a client legitimately sends, so this rejects abuse rather than
        // describing a protocol limit. Matches the existing maxItems bound in
        // PacketRecordDynamic.
        const static uint32_t maxChangeCount = 1000;
    };
}

#endif //OPENMW_PLAYERPACKET_HPP
