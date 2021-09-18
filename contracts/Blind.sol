// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
contract SimpleAuction {
        // Parámetros de la subasta. Los tiempos son ellos
        // marcas de tiempo absolutas de Unix (segundos desde 1970-01-01)
        // o periodos de tiempo en segundos.
        address payable public beneficiary;
        uint public auctionEndTime;

       // Estado actual de la subasta.
        address public highestBidder;
        uint public highestBid;

        // Retiros permitidos de ofertas anteriores
        mapping(address => uint) pendingReturns;

        // Establecido en verdadero al final, no permite ningún cambio.
        // Por defecto inicializado a `falso`.
        bool ended;

       // Eventos que se emitirán en los cambios.
        event HighestBidIncreased(address bidder, uint amount);
        event AuctionEnded(address winner, uint amount);

       // Errores que describen fallas.

        // Los comentarios de triple barra se denominan natspec
        // comentarios. Se mostrarán cuando el usuario
        // se le pide que confirme una transacción o
        // cuando se muestra un error.

        /// The auction has already ended.
        error AuctionAlreadyEnded();
        /// There is already a higher or equal bid.
        error BidNotHighEnough(uint highestBid);
        /// The auction has not ended yet.
        error AuctionNotYetEnded();
        /// The function auctionEnd has already been called.
        error AuctionEndAlreadyCalled();

       /// Cree una subasta simple con `_biddingTime`
        /// segundos de tiempo de oferta en nombre del
        /// dirección del beneficiario `_beneficiary`.
        constructor(
            uint _biddingTime,
            address payable _beneficiary
        ) {
            beneficiary = _beneficiary;
            auctionEndTime = block.timestamp + _biddingTime;
        }

        /// Pujar en la subasta con el valor enviado
        /// junto con esta transacción.
        /// El valor solo se reembolsará si el
        /// no se gana la subasta.
        function bid() public payable {
            // No son necesarios argumentos, todos
            // la información ya es parte de
            // la transacción. La palabra clave pagadero
            // es necesario para que la función
            // poder recibir Ether.

            // Revertir la llamada si la puja
            // el período ha terminado.
            if (block.timestamp > auctionEndTime)
                revert AuctionAlreadyEnded();

            // Si la oferta no es mayor, envíe el
            // devolución de dinero (la declaración de reversión
            // revertirá todos los cambios en este
            // ejecución de la función incluyendo
            // habiendo recibido el dinero).
            if (msg.value <= highestBid)
                revert BidNotHighEnough(highestBid);
            
            if (highestBid != 0) {
               // Devolviendo el dinero simplemente usando
                // maximumBidder.send (maximumBid) es un riesgo de seguridad
                // porque podría ejecutar un contrato que no es de confianza.
                // Siempre es más seguro dejar que los destinatarios
                // retirar su dinero ellos mismos.
                pendingReturns[highestBidder] += highestBid;
            }
            highestBidder = msg.sender;
            highestBid = msg.value;
            emit HighestBidIncreased(msg.sender, msg.value);
        }

        
        /// Retirar una oferta que fue sobrepujada.
        function withdraw() public returns (bool) {
            uint amount = pendingReturns[msg.sender] = 0;

            if (amount > 0) {
                // Es importante establecer esto en cero porque el destinatario
                // puede volver a llamar a esta función como parte de la llamada de recepción
                // antes de que regrese `send`.
                pendingReturns[msg.sender] = 0;

            if (!payable(msg.sender).send(amount)) {
                // No es necesario llamar a throw aquí, solo restablece la cantidad adeuda
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    /// Finalizar la subasta y enviar la oferta más alta
    /// al beneficiario.
    function auctionEnd() public {
        // Es una buena guía para estructurar funciones que interactúan
        // con otros contratos (es decir, llaman a funciones o envían Ether)
        // en tres fases:
        // 1. comprobar condiciones
        // 2. realizar acciones (condiciones potencialmente cambiantes)
        // 3. interactuar con otros contratos
        // Si estas fases se mezclan, el otro contrato podría llamar
        // volver al contrato actual y modificar el estado o la causa
        // efectos (pago de ether) que se realizarán varias veces.
        // Si las funciones llamadas internamente incluyen interacción con externas
        // contratos, también deben considerarse interacción con
        // contratos externos.

        // 1. Condiciones
        if (block.timestamp < auctionEndTime)
            revert AuctionNotYetEnded();
        if (ended)
            revert AuctionEndAlreadyCalled();

        // 2. Efectos
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        // 3. Interaction
        beneficiary.transfer(highestBid);
    }
}