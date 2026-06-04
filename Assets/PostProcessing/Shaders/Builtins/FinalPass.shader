Shader "Hidden/PostProcessing/FinalPass"
{
    HLSLINCLUDE

        #pragma multi_compile __ FXAA FXAA_LOW
        #pragma multi_compile __ FXAA_KEEP_ALPHA

        #pragma vertex VertUVTransform
        #pragma fragment Frag

        #include "../StdLib.hlsl"
        #include "../Colors.hlsl"
        #include "Dithering.hlsl"

        // PS3 and XBOX360 aren't supported in Unity anymore, only use the PC variant
        #define FXAA_PC 1

        #if FXAA_KEEP_ALPHA
            // Luma hasn't been encoded in alpha
            #define FXAA_GREEN_AS_LUMA 1
        #else
            // Luma is encoded in alpha after the first Uber pass
            #define FXAA_GREEN_AS_LUMA 0
        #endif
        //I don't know if Resonite uses the FXAA_LOW variable, but considering how there isn't a way for the user to
        //select low quality FXAA over high quality, I think it should be safe to just remove it.
        //Commenting out instead of deleting just in case it is needed.
        //#if FXAA_LOW
        //    #define FXAA_QUALITY__PRESET 12
        //    #define FXAA_QUALITY_SUBPIX 1.0
        //    #define FXAA_QUALITY_EDGE_THRESHOLD 0.166
        //    #define FXAA_QUALITY_EDGE_THRESHOLD_MIN 0.0625
        //#else
        
        #define FXAA_QUALITY__PRESET 39 //used to be 28
        #define FXAA_QUALITY_SUBPIX 0   //used to be 1.0, which is the max value. Could be a little higher than 0 if the increase in aliasing is too much, though increasing the value directly results in less clarity.
        #define FXAA_QUALITY_EDGE_THRESHOLD 0.063//------|
        #define FXAA_QUALITY_EDGE_THRESHOLD_MIN 0.0312//-|these two are basically how strong the FXAA edge detection is. Lower values = stronger edge detection.
        //-----------------------------------------------|Not changing these for now, just to avoid changing too many values at once.
        //#endif
        #include "FastApproximateAntialiasing.hlsl"

        TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
        float4 _MainTex_TexelSize;

        float4 Frag(VaryingsDefault i) : SV_Target
        {
            half4 color = 0.0;

            // Fast Approximate Anti-aliasing
            #if FXAA || FXAA_LOW
            {
                #if FXAA_HLSL_4 || FXAA_HLSL_5
                    FxaaTex mainTex;
                    mainTex.tex = _MainTex;
                    mainTex.smpl = sampler_MainTex;
                #else
                    FxaaTex mainTex = _MainTex;
                #endif

                color = FxaaPixelShader(
                    i.texcoord,                 // pos
                    0.0,                        // fxaaConsolePosPos (unused)
                    mainTex,                    // tex
                    mainTex,                    // fxaaConsole360TexExpBiasNegOne (unused)
                    mainTex,                    // fxaaConsole360TexExpBiasNegTwo (unused)
                    _MainTex_TexelSize.xy,      // fxaaQualityRcpFrame
                    0.0,                        // fxaaConsoleRcpFrameOpt (unused)
                    0.0,                        // fxaaConsoleRcpFrameOpt2 (unused)
                    0.0,                        // fxaaConsole360RcpFrameOpt2 (unused)
                    FXAA_QUALITY_SUBPIX,
                    FXAA_QUALITY_EDGE_THRESHOLD,
                    FXAA_QUALITY_EDGE_THRESHOLD_MIN,
                    0.0,                        // fxaaConsoleEdgeSharpness (unused)
                    0.0,                        // fxaaConsoleEdgeThreshold (unused)
                    0.0,                        // fxaaConsoleEdgeThresholdMin (unused)
                    0.0                         // fxaaConsole360ConstDir (unused)
                );

                #if FXAA_KEEP_ALPHA
                {
                    color.a = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo).a;
                }
                #endif
            }
            #else
            {
                color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo);
            }
            #endif

            color.rgb = Dither(color.rgb, i.texcoord);
            return color;
        }

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
                #pragma exclude_renderers gles vulkan switch

                #pragma multi_compile __ STEREO_INSTANCING_ENABLED STEREO_DOUBLEWIDE_TARGET
                #pragma target 5.0

            ENDHLSL
        }
    }

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
                #pragma exclude_renderers gles vulkan switch

                #pragma multi_compile __ STEREO_INSTANCING_ENABLED STEREO_DOUBLEWIDE_TARGET
                #pragma target 3.0

            ENDHLSL
        }
    }

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
                #pragma only_renderers gles

                #pragma multi_compile __ STEREO_INSTANCING_ENABLED STEREO_DOUBLEWIDE_TARGET
                #pragma target es3.0

            ENDHLSL
        }
    }

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
                #pragma only_renderers gles vulkan switch

                #pragma multi_compile __ STEREO_DOUBLEWIDE_TARGET //not supporting STEREO_INSTANCING_ENABLED
            ENDHLSL
        }
    }
}
