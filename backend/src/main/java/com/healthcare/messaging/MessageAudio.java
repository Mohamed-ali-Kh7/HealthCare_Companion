package com.healthcare.messaging;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * Contenu audio d'un message vocal, dans une table séparée : les listes de messages
 * ne chargent jamais les octets, seulement le téléchargement explicite.
 */
@Entity
@Table(name = "message_audio")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MessageAudio {

    /** 5 Mo : environ 5 minutes en AAC ou Opus à débit vocal. */
    public static final int MAX_BYTES = 5 * 1024 * 1024;

    /** Même identifiant que le message. */
    @Id
    private Long id;

    @MapsId
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "message_id")
    private Message message;

    @Column(name = "content_type", nullable = false, length = 50)
    private String contentType;

    @Column(name = "size_bytes", nullable = false)
    private int sizeBytes;

    @Lob
    @Basic(fetch = FetchType.LAZY)
    @Column(nullable = false, length = MAX_BYTES)
    private byte[] data;

    public MessageAudio(Message message, String contentType, byte[] data) {
        this.message = message;
        this.contentType = contentType;
        this.sizeBytes = data.length;
        this.data = data;
    }
}
