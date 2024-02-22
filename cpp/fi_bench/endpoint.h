#pragma once

#include "config.h"
#include <rdma/fabric.h>

namespace fi_bench
{

    class Endpoint
    {
    public:
        explicit Endpoint(const EndpointConfig &config);
        ~Endpoint();

        // Disallow copy and assign.
        Endpoint(const Endpoint &) = delete;
        Endpoint &operator=(const Endpoint &) = delete;

        // Initializes the endpoint.
        void Init();

        // Finalizes the endpoint.
        void Finalize();

        // Sends a message.
        void Send(const void *data, size_t length);

        // Receives a message.
        void Recv(void *buffer, size_t length);

    private:
        EndpointConfig config_;
        fid_ep *ep_ = nullptr;
        fid_cq *cq_ = nullptr; // Completion Queue
        fi_context ctx_;       // Context for async operations
    };

} // namespace fi_bench
