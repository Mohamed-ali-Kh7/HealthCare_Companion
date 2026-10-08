package com.healthcare.telemonitoring.dto;

import com.healthcare.telemonitoring.SensorType;

import java.util.List;

public record SensorSeriesResponse(SensorType type, String unit, List<SensorPointResponse> points) {
}
