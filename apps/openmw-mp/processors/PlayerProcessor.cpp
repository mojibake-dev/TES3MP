#include <exception>

#include "PlayerProcessor.hpp"
#include "Networking.hpp"

using namespace mwmp;

template<class T>
typename BasePacketProcessor<T>::processors_t BasePacketProcessor<T>::processors;

bool PlayerProcessor::Process(RakNet::Packet &packet) noexcept
{
    for (auto &processor : processors)
    {
        if (processor.first == packet.data[0])
        {
            Player *player = Players::getPlayer(packet.guid);
            PlayerPacket *myPacket = Networking::get().getPlayerPacketController()->GetPacket(packet.data[0]);
            myPacket->setPlayer(player);

            try
            {
                if (!processor.second->avoidReading)
                    myPacket->Read();
            }
            catch (const std::exception &e)
            {
                LOG_MESSAGE_SIMPLE(TimedLog::LOG_ERROR, "Failed to read %s: %s", processor.second->strPacketID.c_str(), e.what());
                return true;
            }

            processor.second->Do(*myPacket, *player);
            return true;
        }
    }
    return false;
}
