// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

/// @title Voting with delegation.
contract Ballot {
    // Esto declara un nuevo tipo complejo que
    // se usará para variables más tarde.
    // Representará a un solo votante.
    struct Voter {
        uint weight; // el peso se acumula por delegación
        bool voted; // si es cierto, esa persona ya votó
        address delegate; // persona delegada a
        uint vote; // índice de la propuesta votada
    }

    // Este es un tipo para una sola propuesta.
    struct Proposal {
        bytes32 name; // nombre corto (hasta 32 bytes)
        uint voteCount; // número acumulado de votos
    }

    address public chairperson;

    // Esto declara una variable de estado que
    // almacena una estructura `Voter` para cada dirección posible.
    mapping(address => Voter) public voters;

    // Una matriz de tamaño dinámico de estructuras `Proposal`.
    Proposal[] public proposals;

    /// Create a new ballot to choose one of `proposalNames`.
    constructor(bytes32[] memory proposalNames) {
        chairperson = msg.sender;
        voters[chairperson].weight = 1;

        // Para cada uno de los nombres de propuesta proporcionados,
        // crea un nuevo objeto de propuesta y agrégalo
        // hasta el final de la matriz.
        for (uint i = 0; i < proposalNames.length; i++) {
            // `Proposal ({...})` crea un temporal
            // Objeto de propuesta y `proposiciones.push (...)`
            // lo agrega al final de `propuestas`.
            proposals.push(Proposal({
                name: proposalNames[i],
                voteCount: 0
            }));
        }
    }

    // Otorgue a `votante` el derecho a votar en esta boleta.
    // Solo puede ser llamado por `presidente`.
    function giveRightToVote(address voter) public {
        // Si el primer argumento de `require` se evalúa
        // a `falso`, la ejecución termina y todoo
        // cambios en el estado y en los saldos de Ether
        // se revierten.
        // Esto solía consumir todoo el gas en las versiones antiguas de EVM, pero
        // ya no.
        // A menudo es una buena ideaa usar `require` para comprobar si
        // las funciones se llaman correctamente.
        // Como segundo argumento, también puede proporcionar un
        // explicación sobre lo que salió mal.
        require(
            msg.sender == chairperson,
            "Only chairperson can give right to vote."
        );
        require(
            !voters[voter].voted,
            "The voter already voted."
        );
        require(voters[voter].weight == 0);
        voters[voter].weight = 1;
    }

    /// Delegate your vote to the voter `to`.
    function delegate(address to) public {
        // asigna referencia
        Voter storage sender = voters[msg.sender];
        require(!sender.voted, "You already voted.");

        require(to != msg.sender, "Self-delegation is disallowed.");

        // Reenviar la delegación siempre que
        // `a` también delegado.
        // En general, estos bucles son muy peligrosos,
        // porque si corren demasiado, podrían
        // necesita más gas del que está disponible en un bloque.
        // En este caso, la delegación no se ejecutará,
        // pero en otras situaciones, tales bucles pueden
        // hace que un contrato se "atasque" por completo.
        while (voters[to].delegate != address(0)) {
            to = voters[to].delegate;

            // Encontramos un bucle en la delegación, no permitido.
            require(to != msg.sender, "Found loop in delegation.");
        }

        // Como `sender` es una referencia, este
        // modifica `votantes [msg.sender] .voted`
        sender.voted = true;
        sender.delegate = to;
        Voter storage delegate_ = voters[to];
        if (delegate_.voted) {
            // Si el delegado ya votó,
            // agregar directamente al número de votos
            proposals[delegate_.vote].voteCount += sender.weight;
        }else {
            // Si el delegado aún no votó,
            // aumenta su peso.
            delegate_.weight += sender.weight;
        }
    }

    /// Give your vote (including votes delegated to you)
    /// to proposal `proposals[proposal].name`.
    function vote(uint proposal) public {
        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, "Has no right to vote");
        require(!sender.voted, "Already voted.");
        sender.voted = true;
        sender.vote = proposal;

        // Si la `propuesta` está fuera del rango de la matriz,
        // esto arrojará automáticamente y revertirá todoo
        // cambios.
        proposals[proposal].voteCount += sender.weight;
    }

    /// @dev Computes the winning proposal taking all
    /// previous votes into account.
    function winningProposal() public view
            returns (uint winningProposal_)
    {
        uint winningVoteCount = 0;
        for (uint p = 0; p < proposals.length; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    // Llama a la función winProposal () para obtener el índice
    // del ganador contenido en la matriz de propuestas y luego
    // devuelve el nombre del ganador
    function winnerName() public view
            returns (bytes32 winnerName_)
    {
        winnerName_ = proposals[winningProposal()].name;
    }
}