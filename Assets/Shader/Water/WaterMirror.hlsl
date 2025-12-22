#ifndef MIRROR_WATER_INCLUDED
#define MIRROR_WATER_INCLUDED

void Ripple_float(
    float2 UV,
    float2 Center,
    float Time,
    float Frequency,
    float Speed,
    float Amplitude,
    float Decay,
    out float3 Normal,
    out float Height)
{
    float dist = length(UV - Center);
    float wave = dist * Frequency - Time * Speed;
    float distanceDecay = exp(-dist * Decay);
    float timeDecay = exp(-Time * 0.5);

    Height = sin(wave) * Amplitude * distanceDecay * timeDecay;

    float dHeight = cos(wave) * Frequency * Amplitude * distanceDecay * timeDecay;
    float2 dir = (dist > 0.001) ? (UV - Center) / dist : float2(0, 1);

    Normal = normalize(float3(-dir.x * dHeight, 1.0, -dir.y * dHeight));
}

void Ripple_half(
    half2 UV,
    half2 Center,
    half Time,
    half Frequency,
    half Speed,
    half Amplitude,
    half Decay,
    out half3 Normal,
    out half Height)
{
    half dist = length(UV - Center);
    half wave = dist * Frequency - Time * Speed;
    half distanceDecay = exp(-dist * Decay);
    half timeDecay = exp(-Time * 0.5);

    Height = sin(wave) * Amplitude * distanceDecay * timeDecay;

    half dHeight = cos(wave) * Frequency * Amplitude * distanceDecay * timeDecay;
    half2 dir = (dist > 0.001) ? (UV - Center) / dist : half2(0, 1);

    Normal = normalize(half3(-dir.x * dHeight, 1.0, -dir.y * dHeight));
}

void Fresnel_float(
    float3 ViewDir,
    float3 Normal,
    float Power,
    out float Out)
{
    float NdotV = saturate(dot(Normal, ViewDir));
    Out = pow(1.0 - NdotV, Power);
    Out = lerp(0.02, 1.0, Out);
}

void Fresnel_half(
    half3 ViewDir,
    half3 Normal,
    half Power,
    out half Out)
{
    half NdotV = saturate(dot(Normal, ViewDir));
    Out = pow(1.0 - NdotV, Power);
    Out = lerp(0.02, 1.0, Out);
}

#endif
