#import "FOXNumericGenerators.h"
#import "FOXCoreGenerators.h"
#import "FOXRoseTree.h"
#import "FOXChooseGenerator.h"
#import "FOXLimits.h"
#import <float.h>
#import "FOXDeterministicRandom.h"
#import "FOXSequenceRandom.h"

static id<FOXGenerator> _FOXNaturalInteger(void) {
    return FOXMap(FOXInteger(), ^id(NSNumber *number) {
        return @(ABS([number integerValue]));
    });
}

FOX_EXPORT id<FOXGenerator> FOXBoolean(void) {
    return FOXWithName(@"FOXBoolean", FOXChoose(@0, @1));
}

FOX_EXPORT id<FOXGenerator> FOXInteger(void) {
    return FOXWithName(@"Integer", FOXSized(^(NSUInteger sizeNumber) {
        return FOXChoose(@(-((NSInteger)sizeNumber)), @(sizeNumber));
    }));
}

FOX_EXPORT id<FOXGenerator> FOXPositiveInteger(void) {
    return FOXWithName(@"PositiveInteger", _FOXNaturalInteger());
}

FOX_EXPORT id<FOXGenerator> FOXNegativeInteger(void) {
    return FOXWithName(@"NegativeInteger", FOXMap(_FOXNaturalInteger(), ^id(NSNumber *number) {
        return @(-[number integerValue]);
    }));
}

FOX_EXPORT id<FOXGenerator> FOXStrictPositiveInteger(void) {
    return FOXWithName(@"StrictPostiveInteger", FOXMap(_FOXNaturalInteger(), ^id(NSNumber *number) {
        return @([number integerValue] ?: 1);
    }));
}

FOX_EXPORT id<FOXGenerator> FOXStrictNegativeInteger(void) {
    return FOXWithName(@"StrictNegativeInteger", FOXMap(_FOXNaturalInteger(), ^id(NSNumber *number) {
        return @(-([number integerValue] ?: 1));
    }));
}

FOX_EXPORT id<FOXGenerator> FOXNonZeroInteger(void) {
    return FOXWithName(@"NonZeroInteger", FOXMap(FOXInteger(), ^id(NSNumber *number) {
        return @([number integerValue] ?: 1);
    }));
}

FOX_INLINE id<FOXGenerator> FOXRational(long long minMantissa, long long maxMantissa,
                                        long long minExponent, long long maxExponent,
                                        id(^converter)(NSNumber *mantissa, NSNumber *exponent)) {

    id<FOXGenerator> gen = FOXSized(^id<FOXGenerator>(NSUInteger size) {
        // we want to shrink to the smallest (negative) exponent, not zero.
        NSNumber *minExponentNumber = @0;
        NSNumber *maxExponentNumber = @(MAX(1, MIN(size - minExponent, (maxExponent - minExponent))));
        id<FOXGenerator> expGenerator = FOXChoose(minExponentNumber, maxExponentNumber);
        return FOXBind(expGenerator, ^id<FOXGenerator>(NSNumber *exponent) {
            NSNumber *minMantissaNumber = @(MAX(-(long long)size, minMantissa));
            NSNumber *maxMantissaNumber = @(MIN(size, maxMantissa));
            id<FOXGenerator> mantissaGenerator = FOXChoose(minMantissaNumber, maxMantissaNumber);
            return FOXBind(mantissaGenerator, ^id<FOXGenerator>(NSNumber *mantissa) {
                return FOXReturn(converter(mantissa, exponent));
            });
        });
    });

    return FOXWithName(@"Rational", gen);
}

FOX_EXPORT id<FOXGenerator> FOXFloat(void) {
    const int minMantissa = -4194303;
    const int maxMantissa = 4194304;
    const unsigned int minExponent = 0;
    const unsigned int maxExponent = 0xff;
    NSNumber *(^floatFactory)(NSNumber *, NSNumber *) = ^(NSNumber *mantissaNumber, NSNumber *exponentNumber) {
        float value = 0;
        unsigned int *valueInt = (unsigned int *)&value;
        unsigned int mantissa = ABS([mantissaNumber intValue]) & 0x7fffff;
        unsigned int exponent = ABS([exponentNumber intValue]) & 0xffff;
        unsigned int sign = ([mantissaNumber intValue] > 0 ? 1 : 0);
        *valueInt = (mantissa | (exponent << 23) | (sign << 31));
        return @(value);
    };
    return FOXWithName(@"Float", FOXRational(minMantissa, maxMantissa,
                                             minExponent, maxExponent,
                                             floatFactory));
}

FOX_EXPORT id<FOXGenerator> FOXDouble(void) {
    const long long minMantissa = -2251799813685246;
    const long long maxMantissa = 2251799813685248;
    const unsigned int minExponent = 0;
    const unsigned int maxExponent = 0x7ff;
    NSNumber *(^doubleFactory)(NSNumber *, NSNumber *) = ^(NSNumber *mantissaNumber, NSNumber *exponentNumber) {
        double value = 0;
        unsigned long long *valueInt = (unsigned long long *)&value;
        unsigned long long mantissa = ABS([mantissaNumber longLongValue]) & 0x7fffff;
        unsigned long long exponent = ABS([exponentNumber intValue]) & 0xffff;
        unsigned long long sign = ([mantissaNumber intValue] > 0 ? 1 : 0);
        *valueInt = (mantissa | (exponent << 52) | (sign << 63));
        return @(value);
    };
    return FOXWithName(@"Double", FOXRational(minMantissa, maxMantissa,
                                              minExponent, maxExponent,
                                              doubleFactory));
}

FOX_EXPORT id<FOXGenerator> FOXDecimalNumber(void) {
    id<FOXGenerator> gen = FOXSized(^id<FOXGenerator>(NSUInteger size) {
        return FOXGenBind(FOXBoolean(), ^id<FOXGenerator>(FOXRoseTree *isNegativeTree) {
            NSNumber *isNegative = isNegativeTree.value;
            return FOXBind(FOXChoose(@0, @(size)), ^id<FOXGenerator>(NSNumber *mantissa) {
                NSNumber *minExponent = @0;
                NSNumber *maxExponent = @(INT8_MAX - INT8_MIN);
                id<FOXGenerator> exponentGenerator = [[FOXChooseGenerator alloc] initWithLowerBound:minExponent
                                                                                         upperBound:maxExponent];
                return FOXBind(exponentGenerator, ^id<FOXGenerator>(NSNumber *exponent) {
                    NSDecimalNumber *number;
                    short exp = [exponent integerValue] + INT8_MIN;
                    if ([mantissa isEqual:@0]) {
                        number = [NSDecimalNumber zero];
                    } else {
                        number = [NSDecimalNumber decimalNumberWithMantissa:[mantissa unsignedLongLongValue]
                                                                   exponent:exp
                                                                 isNegative:[isNegative boolValue]];
                    }
                    return FOXReturn(number);
                });
            });
        });
    });

    gen = FOXGenMap(gen, ^FOXRoseTree *(FOXRoseTree *generatedTree) {
        NSDecimalNumber *originalValue = generatedTree.value;
        NSDecimalNumber *zero = [NSDecimalNumber zero];
        if ([originalValue compare:zero] == NSOrderedDescending) {
            return [generatedTree treeFilterChildrenByBlock:^BOOL(NSDecimalNumber *element) {
                return [element compare:originalValue] == NSOrderedAscending;
            }];
        } else {
            return [generatedTree treeFilterChildrenByBlock:^BOOL(NSDecimalNumber *element) {
                return [element compare:originalValue] == NSOrderedDescending;
            }];
        }
    });

    return FOXWithName(@"DecimalNumber", gen);
}

#pragma mark - Famous Generators

FOX_EXPORT id<FOXGenerator> FOXFamousInteger(void) {
    return FOXWithName(@"FamousInteger",
                       FOXFrequency(@[@[@48, FOXInteger()],
                                      @[@1, FOXReturn(@(INT_MAX))],
                                      @[@1, FOXReturn(@(INT_MIN))]]));
}

FOX_EXPORT id<FOXGenerator> FOXFamousPositiveInteger(void) {
    return FOXWithName(@"FamousPositiveInteger",
                       FOXFrequency(@[@[@48, FOXPositiveInteger()],
                                      @[@2, FOXReturn(@(INT_MAX))]]));
}

FOX_EXPORT id<FOXGenerator> FOXFamousNegativeInteger(void) {
    return FOXWithName(@"FamousNegativeInteger",
                       FOXFrequency(@[@[@48, FOXNegativeInteger()],
                                      @[@2, FOXReturn(@(INT_MIN))]]));
}

FOX_EXPORT id<FOXGenerator> FOXFamousStrictNegativeInteger(void) {
    return FOXWithName(@"FamousStrictNegativeInteger",
                       FOXFrequency(@[@[@48, FOXStrictNegativeInteger()],
                                      @[@2, FOXReturn(@(INT_MIN))]]));
}

FOX_EXPORT id<FOXGenerator> FOXFamousStrictPositiveInteger(void) {
    return FOXWithName(@"FamousStrictPositiveInteger",
                       FOXFrequency(@[@[@48, FOXStrictPositiveInteger()],
                                      @[@2, FOXReturn(@(INT_MAX))]]));
}

FOX_EXPORT id<FOXGenerator> FOXFamousNonZeroInteger(void) {
    return FOXWithName(@"FamousNonZeroInteger",
                       FOXFrequency(@[@[@48, FOXNonZeroInteger()],
                                      @[@1, FOXReturn(@(INT_MIN))],
                                      @[@1, FOXReturn(@(INT_MAX))]]));
}

FOX_EXPORT id<FOXGenerator> FOXFamousFloat(void) {
    return FOXWithName(@"FamousFloat",
                       FOXFrequency(@[@[@44, FOXFloat()],
                                      @[@1, FOXReturn(@(-0.f))],
                                      @[@1, FOXReturn(@(FOXFloatMax()))],
                                      @[@1, FOXReturn(@(-FOXFloatMax()))],
                                      @[@1, FOXReturn(@(FOXFloatInfinity()))],
                                      @[@1, FOXReturn(@(-FOXFloatInfinity()))],
                                      @[@1, FOXReturn(@(FOXFloatQNaN()))]]));
}

FOX_EXPORT id<FOXGenerator> FOXFamousDouble(void) {
    return FOXWithName(@"FamousDouble",
                       FOXFrequency(@[@[@44, FOXDouble()],
                                      @[@1, FOXReturn(@(-0.0))],
                                      @[@1, FOXReturn(@(FOXDoubleMax()))],
                                      @[@1, FOXReturn(@(-FOXDoubleMax()))],
                                      @[@1, FOXReturn(@(FOXDoubleInfinity()))],
                                      @[@1, FOXReturn(@(-FOXDoubleInfinity()))],
                                      @[@1, FOXReturn(@(FOXDoubleQNaN()))]]));
}

FOX_EXPORT id<FOXGenerator> FOXFamousDecimalNumber(void) {
    return FOXWithName(@"FamousDecimalNumber",
                       FOXFrequency(@[@[@48, FOXDecimalNumber()],
                                      @[@1, FOXReturn([NSDecimalNumber minimumDecimalNumber])],
                                      @[@1, FOXReturn([NSDecimalNumber maximumDecimalNumber])],
                                      @[@1, FOXReturn([NSDecimalNumber notANumber])]]));
}

FOX_EXPORT id<FOXGenerator> FOXSeed(void) {
    return FOXBind(FOXPositiveInteger(), ^id<FOXGenerator>(NSNumber *value) {
        id<FOXRandom> random = [[FOXDeterministicRandom alloc] initWithSeed:[value unsignedIntegerValue]];
        return FOXReturn(random);
    });
}
